import Rice.MessageDialog.MessageDialogStatics;
import Vino.Camera.Actors.MenuCameraUser;
import Rice.MainMenu.MainMenuSkipCutsceneOverlay;
import Peanuts.Audio.HazeAudioManager.AudioManagerStatics;
import Rice.MainMenu.TrialUpsellWidget;
import Rice.MainMenu.MainMenuAmbienceManager;

event void FOnMainMenuStateChanged(EMainMenuState PreviousState, EMainMenuState NewState);
event void FOnMainMenuTransition(bool bSnap, EMainMenuState PreviousState);
event void FOnMainMenuTransitionAbort();
event void FOnPlayerAnySelectionStatusChange(EHazePlayer Player, bool bSelectedByAnyPlayer);
event void FOnMainMenuEvent();

const FConsoleVariable CVar_PreloadOnMainMenu("Haze.PreloadOnMainMenu", 1);
const FConsoleVariable CVar_MainMenuDebugBusyTask("Haze.MainMenuDebugBusyTask", 0);

enum EMainMenuState
{
	None,
	Splash,
	MainMenu,
	ChapterSelect,
	CharacterSelect,
	Options,
	BusyTask,
	Credits,
	// Note: change how the StateWidgets array gets
	// filled as well if you change this enum.
};

class UMainMenuStateWidget : UHazeUserWidget
{
	UPROPERTY(BlueprintReadOnly, NotEditable)
	AMainMenu MainMenu;
	UPROPERTY(BlueprintReadOnly, NotEditable)
	EMainMenuState PreviousMainMenuState;
	UPROPERTY(BlueprintReadOnly, NotEditable)
	EMainMenuState NextMainMenuState;

	UPROPERTY()
	bool bShowDuringTransition = false;
	UPROPERTY()
	bool bIsActive = false;

	default bIsFocusable = true;
	default Visibility = ESlateVisibility::Visible;

	UFUNCTION(BlueprintEvent)
	void Show(bool bSnap)
	{
		if (!bIsActive)
			return;
		SetVisibility(ESlateVisibility::Visible);
	}

	void PreHide()
	{
		SetVisibility(ESlateVisibility::HitTestInvisible);
	}

	UFUNCTION(BlueprintEvent)
	void Hide(bool bSnap)
	{
		if (bIsActive)
			return;
		SetVisibility(ESlateVisibility::Collapsed);
	}

	UFUNCTION(BlueprintOverride)
	FEventReply OnFocusReceived(FGeometry Geom, FFocusEvent Event)
	{
		// If the main menu itself gets focus, set focus to our initial position
		//  This happens if, for example, the background is clicked
		auto InitialFocus = GetInitialFocusWidget();
		if (InitialFocus != nullptr && InitialFocus != this)
		{		
			return FEventReply::Handled().SetUserFocus(InitialFocus);
		}

		// Anyone that isn't the owner of the menu will always
		// have focus on the menu itself, so the menu can take input
		// from this user, but it can't press buttons inside it.
		return FEventReply::Unhandled();
	}

	UFUNCTION(BlueprintEvent)
	UWidget GetInitialFocusWidget()
	{
		return nullptr;
	}

	UFUNCTION(BlueprintOverride)
	FEventReply OnMouseButtonDown(FGeometry Geom, FPointerEvent Event)
	{
		// Consume all mouse clicks by default so we keep focus
		return FEventReply::Handled();
	}

	UFUNCTION(BlueprintOverride)
	FEventReply OnKeyDown(FGeometry Geom, FKeyEvent Event)
	{
		// Allow the owner to give input normally, they are using the UI
		if (MainMenu.IsOwnerInput(Event))
			return FEventReply::Unhandled();

		// Don't handle input from invalid identities at this point
		if (MainMenu.IsInvalidInput(Event))
			return FEventReply::Unhandled();

		// Don't absorb certain special keys
		if (Event.Key == EKeys::Escape || Event.Key == EKeys::Gamepad_Special_Left || Event.Key == EKeys::Tab)
			return FEventReply::Unhandled();

		// Don't absorb if focus is something outside of the game (ie console)
		if (Widget::IsSlateUserFocusOutsideGame(Event.UserIndex))
			return FEventReply::Unhandled();

		// By default we ignore all input from users that aren't the main menu's owner,
		// certain widgets such as the local lobby will override this behavior.
		return FEventReply::Handled();
	}
};

class AMainMenu : AHazeActor
{
	default PrimaryActorTick.bTickEvenWhenPaused = true;

	UPROPERTY(BlueprintReadOnly, NotEditable)
	EMainMenuState State = EMainMenuState::None;

	UPROPERTY(BlueprintReadOnly, NotEditable)
	UHazePlayerIdentity OwnerIdentity;

	UPROPERTY()
	AMenuCameraUser CameraUser;

	UPROPERTY()
	AMainMenuAmbienceManager AmbienceManager;

	UPROPERTY()
	FOnMainMenuTransition OnSplashStartedLoadingProfile;

	UPROPERTY()
	FOnMainMenuTransition OnSplashProfileLoadFailed;

	UPROPERTY()
	FOnMainMenuStateChanged OnMainMenuStateChanged;

	UPROPERTY()
	FOnMainMenuTransition OnTransitionToSplashScreen;

	UPROPERTY()
	FOnMainMenuTransition OnTransitionToMainMenu;

	UPROPERTY()
	FOnMainMenuTransition OnTransitionToChapterSelect;

	UPROPERTY()
	FOnMainMenuTransition OnTransitionToCharacterSelect;

	UPROPERTY()
	FOnMainMenuTransition OnTransitionToCredits;

	UPROPERTY()
	FOnMainMenuTransitionAbort OnTransitionAbort;

	UPROPERTY()
	FOnMainMenuEvent OnGameProbablyStartingSoon;

	UPROPERTY()
	FOnPlayerAnySelectionStatusChange OnPlayerSelectionStatusChange;

	UPROPERTY()
	TSubclassOf<UMainMenuStateWidget> SplashWidget;

	UPROPERTY()
	TSubclassOf<UMainMenuStateWidget> MainMenuWidget;

	UPROPERTY()
	TSubclassOf<UMainMenuStateWidget> OptionsWidget;

	UPROPERTY()
	TSubclassOf<UMainMenuStateWidget> ChapterSelectWidget;

	UPROPERTY()
	TSubclassOf<UMainMenuStateWidget> CharacterSelectWidget;

	UPROPERTY()
	TSubclassOf<UMainMenuStateWidget> BusyTaskWidget;

	UPROPERTY()
	TSubclassOf<UMainMenuStateWidget> CreditsWidget;

	UMainMenuSkipCutsceneOverlay SkipCutsceneOverlay;
	
	private TArray<UMainMenuStateWidget> StateWidgets;
	private EMainMenuState TransitionPrevious = EMainMenuState::None;
	private EMainMenuState TransitionNext = EMainMenuState::None;
	private bool bIsTransitioning = false;
	private bool bIsTransitionFinished = false;
	private bool bTransitionSnap = false;
	private TPerPlayer<bool> PrevPlayerSelectionStatus;
	private EHazeRichPresence AppliedRichPresence = EHazeRichPresence::MainMenu;
	private AStaticCamera CurrentCamera;
	private bool bIsTransitioningCamera = false;
	private float CameraTransitionBlendTime = 0.f;
	private bool bIsPreloading = false;
	bool bIsNewLobby = true;

	bool IsTransitioning()
	{
		return bIsTransitioning;
	}

	bool IsOwnerInput(FFocusEvent FocusEvent)
	{
		if (OwnerIdentity == nullptr)
			return false;
		return OwnerIdentity.TakesInputFromControllerId(FocusEvent.User);
	}

	bool IsOwnerInput(FKeyEvent Event)
	{
		if (OwnerIdentity == nullptr)
			return false;
		return OwnerIdentity.TakesInputFromControllerId(Event.ControllerId);
	}

	bool IsInvalidInput(FKeyEvent Event)
	{
		auto Identity = Online::GetLocalIdentityAssociatedWithInputDevice(Event.ControllerId);
		return Identity == nullptr;
	}

	UFUNCTION(BlueprintOverride)
	void EndPlay(EEndPlayReason Reason)
	{
		if (State != EMainMenuState::None)
			CloseMainMenu();

		WidgetBlueprint::SetFocusToGameViewport();
	}

	void CloseMainMenu()
	{
		// Destroy all menu widgets when moving away from the main menu
		for (auto Widget : StateWidgets)
		{
			if (Widget != nullptr)
				Widget::RemoveFullscreenWidget(Widget);
		}

		StateWidgets.Empty();

		// We don't reset the online system's primary identity here,
		// because we could be closing the menu and going in-game.
		// Primary identity will be reset the next time we go to splash.
		OwnerIdentity = nullptr;

		// Make sure the game is focused after we leave the menu
		Widget::SetUseMouseCursor(false);
		WidgetBlueprint::SetFocusToGameViewport();
		State = EMainMenuState::None;
	}

	UMainMenuStateWidget GetActiveMenuWidget()
	{
		if (State == EMainMenuState::None)
			return nullptr;
		return StateWidgets[int(State)];
	}

	bool IsInLobby()
	{
		return State == EMainMenuState::ChapterSelect || State == EMainMenuState::CharacterSelect;
	}

	UFUNCTION(BlueprintOverride)
	void Tick(float DeltaTime)
	{
		UpdatePlayerSelectionStatus();
		UpdateMainMenuRichPresence();
		UpdateLevelPreload();

		// Don't do anything if the menu isn't shown at all
		if (State == EMainMenuState::None)
			return;

		// Busy task text from the online system always has precedence if we have a OwnerIdentity
		if (HasBusyTask() && OwnerIdentity != nullptr)
		{
			if (State != EMainMenuState::BusyTask)
				SwitchToState(EMainMenuState::BusyTask, bSnap=false);
		}
		// Return to splash if our primary identity is different from the menu owner
		else if (Online::PrimaryIdentity != OwnerIdentity && Online::PrimaryIdentity != nullptr && OwnerIdentity != nullptr)
		{
			Lobby::Menu_LeaveLobby();
			ReturnToSplashScreen(Online::PrimaryIdentity, true);
		}
		else if (State != EMainMenuState::Splash)
		{
			// Back to main menu from busy task
			if (State == EMainMenuState::BusyTask)
			{
				if (OwnerIdentity != nullptr)
					SwitchToState(EMainMenuState::MainMenu, bSnap=false);
				else
					SwitchToState(EMainMenuState::Splash, bSnap=false);
			}

			// If the lobby game has started, always close the menu
			auto Lobby = Lobby::GetLobby();
			if (Lobby != nullptr && Lobby.HasGameStarted())
			{
				CloseMainMenu();
				return;
			}

			// If a lobby is up, always be in the lobby state
			if (!IsInLobby() && Lobby != nullptr && !Lobby.HasGameStarted())
			{
				SwitchToState(EMainMenuState::ChapterSelect, bSnap=false);
			}

			// We can never be in the lobby state without a lobby being up
			if (IsInLobby() && Lobby == nullptr)
			{
				SwitchToState(EMainMenuState::MainMenu, bSnap=false);
				bIsNewLobby = true;
			}
		}

		if (!IsMessageDialogShown() && !bIsTransitioning && !IsTrialUpsellActive())
		{
			auto ActiveWidget = GetActiveMenuWidget();
			if (ActiveWidget != nullptr && Widget::IsAnyUserFocusGameViewportOrNone())
			{
				Widget::SetAllPlayerUIFocusBeneathParent(ActiveWidget);
			}
		}

		// Update the overlay widget when we're playing a cutscene
		// this captures skip input
		if (CameraUser.ActiveLevelSequenceActor != nullptr)
		{
			if (SkipCutsceneOverlay == nullptr)
			{
				SkipCutsceneOverlay = Cast<UMainMenuSkipCutsceneOverlay>(Widget::AddFullscreenWidget(
					UMainMenuSkipCutsceneOverlay::StaticClass(),
					EHazeWidgetLayer::Menu
				));
				SkipCutsceneOverlay.CameraUser = CameraUser;
				Widget::SetAllPlayerUIFocus(SkipCutsceneOverlay);
			}

			if (Widget::IsAnyUserFocusGameViewportOrNone())
				Widget::SetAllPlayerUIFocus(SkipCutsceneOverlay);
		}
		else
		{
			if (SkipCutsceneOverlay != nullptr)
			{
				Widget::RemoveFullscreenWidget(SkipCutsceneOverlay);
				SkipCutsceneOverlay = nullptr;
			}
		}
	}

	bool CanSwitchToState(EMainMenuState NewState)
	{
		// Only allow switching back to splash if our primary identity doesn't match
		if (Online::PrimaryIdentity != OwnerIdentity)
		{
			if (NewState != EMainMenuState::Splash)
				return false;
		}
		return true;
	}

	UFUNCTION()
	void ReturnToMainMenu(bool bSnap = false)
	{
		if (!CanSwitchToState(EMainMenuState::MainMenu))
			return;
		SwitchToState(EMainMenuState::MainMenu, bSnap);
	}

	UFUNCTION()
	void ReturnToChapterSelect()
	{
		if (!CanSwitchToState(EMainMenuState::ChapterSelect))
			return;
		SwitchToState(EMainMenuState::ChapterSelect, bSnap = false);
	}

	UFUNCTION()
	void ProceedToCharacterSelect()
	{
		if (!CanSwitchToState(EMainMenuState::CharacterSelect))
			return;
		SwitchToState(EMainMenuState::CharacterSelect, bSnap = false);
	}

	UFUNCTION()
	void ShowOptionsMenu()
	{
		if (!CanSwitchToState(EMainMenuState::Options))
			return;
		SwitchToState(EMainMenuState::Options, bSnap = false);
	}

	UFUNCTION()
	void ShowCredits()
	{
		if (!CanSwitchToState(EMainMenuState::Credits))
			return;
		SwitchToState(EMainMenuState::Credits, bSnap = false);
	}

	UFUNCTION()
	void ReturnToSplashScreen(UHazePlayerIdentity WithIdentity = nullptr, bool bSnap = false)
	{
		if (!CanSwitchToState(EMainMenuState::Splash))
			return;
		OwnerIdentity = nullptr;
		Online::SetPrimaryIdentity(WithIdentity);
		SwitchToState(EMainMenuState::Splash, bSnap = bSnap);
	}

	UFUNCTION()
	void ConfirmMenuOwner(UHazePlayerIdentity Identity, bool bSnap = false)
	{
		ensure(State == EMainMenuState::Splash);
		ensure(OwnerIdentity == nullptr);

		GameSettings::SetGameSettingsProfile(Identity);
		OwnerIdentity = Identity;
		Online::SetPrimaryIdentity(OwnerIdentity);
		SwitchToState(EMainMenuState::MainMenu, bSnap);
		Online::UpdateRichPresence(EHazeRichPresence::MainMenu);
	}

	UFUNCTION()
	void TransitionToCamera(AStaticCamera Camera, bool bSnap, float BlendTime = 3.f, UAkAudioEvent WooshSound = nullptr, float DelayTime = 0.f)
	{
		// Clear previous blend
		if (bIsTransitioningCamera)
		{
			bIsTransitioningCamera = false;
			System::ClearTimer(this, n"OnCameraTransitionCompleted");
			System::ClearTimer(this, n"OnCameraTransitionStarted");
		}

		// Snap to new camera if needed
		if (bSnap || CurrentCamera == Camera || CurrentCamera == nullptr)
		{
			CurrentCamera = Camera;
			CameraUser.FadeInView(0.f);
			if (CameraUser.ActiveLevelSequenceActor == nullptr)
				CameraUser.SnapToCamera(Camera);

			bIsTransitioningCamera = false;
			OnCameraTransitionCompleted();				
		}
		else
		{
			bIsTransitioningCamera = true;
			CameraTransitionBlendTime = BlendTime;

			CameraUser.FadeInView(0.5f);
			CurrentCamera = Camera;

			if (DelayTime > 0.f)
				System::SetTimer(this, n"OnCameraTransitionStarted", DelayTime, bLooping=false);
			else if (CameraUser.ActiveLevelSequenceActor == nullptr)
				CameraUser.BlendToCamera(Camera, BlendTime);

			if (WooshSound != nullptr)
				UHazeAkComponent::HazePostEventFireForget(WooshSound, FTransform::Identity, bUseReverb=false);

			if (BlendTime > 0.f)
				System::SetTimer(this, n"OnCameraTransitionCompleted", BlendTime, bLooping=false);
			else
				OnCameraTransitionCompleted();			
		}

	}

	UFUNCTION()
	private void OnCameraTransitionCompleted()
	{
		if (bIsTransitioningCamera)
		{
			bIsTransitioningCamera = false;
			if (bIsTransitioning && bIsTransitionFinished)
				FinishTransition();
		}
	}

	UFUNCTION()
	private void OnCameraTransitionStarted()
	{
		if (CameraUser.ActiveLevelSequenceActor == nullptr)
			CameraUser.BlendToCamera(CurrentCamera, CameraTransitionBlendTime);
	}

	UMainMenuStateWidget GetMainMenuWidget(EMainMenuState State)
	{
		return StateWidgets[int(State)];
	}

	private void SwitchToState(EMainMenuState NewState, bool bSnap)
	{
		if (!CanSwitchToState(NewState))
			return;

		if (bIsTransitioningCamera)
		{
			bIsTransitioningCamera = false;
			System::ClearTimer(this, n"OnCameraTransitionCompleted");
		}

		if (bIsTransitioning)
		{
			if (CameraUser.ActiveLevelSequenceActor != nullptr)
				CameraUser.ActiveLevelSequenceActor.Stop(true);

			System::ClearTimer(this, n"FinishTransitionAfterDelay");
			OnTransitionAbort.Broadcast();
			FinishTransition();
		}

		auto PreviousState = State;

		if (StateWidgets[int(PreviousState)] != nullptr)
		{
			StateWidgets[int(PreviousState)].bIsActive = false;
			StateWidgets[int(PreviousState)].NextMainMenuState = NewState;
			StateWidgets[int(PreviousState)].PreHide();
			StateWidgets[int(PreviousState)].Hide(bSnap);
			Widget::DisableAllPlayerUIFocus();
		}

		State = NewState;

		TransitionPrevious = PreviousState;
		TransitionNext = NewState;
		bTransitionSnap = bSnap;
		bIsTransitioning = true;
		bIsTransitionFinished = false;

		bool bHadTransition = false;
		switch (NewState)
		{
			case EMainMenuState::Splash:
				OnTransitionToSplashScreen.Broadcast(bSnap, PreviousState);
				bHadTransition = OnTransitionToSplashScreen.IsBound();
					UHazeAkComponent::HazeSetGlobalRTPCValue("Rtpc_World_MainMenu_Progression", 0.f, 1500.f);
			break;
			case EMainMenuState::MainMenu:
				OnTransitionToMainMenu.Broadcast(bSnap, PreviousState);
				AmbienceManager.StartLerpingListeners(EMenuAmbienceTransitionState::MenuStart, 3.f);
				UHazeAkComponent::HazeSetGlobalRTPCValue("Rtpc_World_MainMenu_Progression", 1.f, 100.f);
				if(PreviousState != EMainMenuState::Splash)
					GetAudioManager().UI_ReturnToMenuRoot();
				bHadTransition = OnTransitionToMainMenu.IsBound();
			break;
			case EMainMenuState::ChapterSelect:
				OnTransitionToChapterSelect.Broadcast(bSnap, PreviousState);
				bHadTransition = OnTransitionToChapterSelect.IsBound();
				AmbienceManager.StartLerpingListeners(EMenuAmbienceTransitionState::MenuStart, 1.f);
				UHazeAkComponent::HazeSetGlobalRTPCValue("Rtpc_World_MainMenu_Progression", 2.f, 100.f);
			break;
			case EMainMenuState::CharacterSelect:
				OnTransitionToCharacterSelect.Broadcast(bSnap, PreviousState);
				bHadTransition = OnTransitionToCharacterSelect.IsBound();
				UHazeAkComponent::HazeSetGlobalRTPCValue("Rtpc_World_MainMenu_Progression", 3.f, 250.f);
				AmbienceManager.StartLerpingListeners(EMenuAmbienceTransitionState::RoseRoom, 1.f);
				GetAudioManager().UI_OnSelectionConfirmed();
			break;
		}

		auto Widget = StateWidgets[int(TransitionNext)];
		if (!bHadTransition || (Widget != nullptr && Widget.bShowDuringTransition))
			FinishTransition();
	}

	UFUNCTION()
	private void FinishTransitionAfterDelay()
	{
		FinishTransition(false, 0.f);
	}

	UFUNCTION()
	void FinishTransition(bool bWaitForCamera = true, float FinishDelay = 0.f)
	{
		if (!bIsTransitioning)
			return;

		if (FinishDelay > 0.f)
		{
			System::SetTimer(this, n"FinishTransitionAfterDelay", FinishDelay, bLooping=false);
			return;
		}

		auto Widget = StateWidgets[int(State)];
		if (bIsTransitioningCamera && (Widget == nullptr || !Widget.bShowDuringTransition) && bWaitForCamera)
		{
			bIsTransitionFinished = true;
			return;
		}

		auto TransitionedTo = TransitionNext;
		auto TransitionedFrom = TransitionPrevious;
		OnMainMenuStateChanged.Broadcast(TransitionPrevious, TransitionNext);

		Widget::SetUseMouseCursor(true);
		TransitionPrevious = EMainMenuState::None;
		TransitionNext = EMainMenuState::None;
		bIsTransitioning = false;
		bIsTransitionFinished = true;

		if (StateWidgets[int(State)] != nullptr)
		{
			// Tell the widget to be visible
			Widget.bIsActive = true;
			Widget.PreviousMainMenuState = TransitionedFrom;
			Widget.Show(bTransitionSnap);

			// Make sure our owner's focus is set to the right place
			if (State == TransitionedTo)
			{
				if (!IsMessageDialogShown() && !IsTrialUpsellActive())
				{
					auto FocusTarget = Widget.GetInitialFocusWidget();
					if (FocusTarget != nullptr)
						Widget::SetAllPlayerUIFocus(FocusTarget);
					else
						Widget::SetAllPlayerUIFocus(Widget);
				}
			}
		}
	}

	UFUNCTION()
	void ShowMainMenu()
	{
		ensure(State == EMainMenuState::None);
		OwnerIdentity = nullptr;

		StateWidgets.Add(nullptr);
		StateWidgets.Add(Cast<UMainMenuStateWidget>(Widget::AddFullscreenWidget(SplashWidget, EHazeWidgetLayer::Menu)));
		StateWidgets.Add(Cast<UMainMenuStateWidget>(Widget::AddFullscreenWidget(MainMenuWidget, EHazeWidgetLayer::Menu)));
		StateWidgets.Add(Cast<UMainMenuStateWidget>(Widget::AddFullscreenWidget(ChapterSelectWidget, EHazeWidgetLayer::Menu)));
		StateWidgets.Add(Cast<UMainMenuStateWidget>(Widget::AddFullscreenWidget(CharacterSelectWidget, EHazeWidgetLayer::Menu)));
		StateWidgets.Add(Cast<UMainMenuStateWidget>(Widget::AddFullscreenWidget(OptionsWidget, EHazeWidgetLayer::Menu)));
		StateWidgets.Add(Cast<UMainMenuStateWidget>(Widget::AddFullscreenWidget(BusyTaskWidget, EHazeWidgetLayer::Menu)));
		StateWidgets.Add(Cast<UMainMenuStateWidget>(Widget::AddFullscreenWidget(CreditsWidget, EHazeWidgetLayer::Menu)));

		for (auto Widget : StateWidgets)
		{
			if (Widget != nullptr)
			{
				Widget.SetWidgetZOrderInLayer(-100);
				Widget.MainMenu = this;
				Widget.bIsActive = false;
				Widget.Hide(bSnap = true);
			}
		}

		SwitchToState(EMainMenuState::Splash, bSnap = true);
	}

	UFUNCTION()
	bool HasBusyTask()
	{
		if (CVar_MainMenuDebugBusyTask.GetInt() != 0)
			return true;
		FText OutText;
		return Online::HasBusyTask(OutText);
	}

	UFUNCTION(BlueprintPure)
	FText GetBusyTaskText()
	{
		if (CVar_MainMenuDebugBusyTask.GetInt() != 0)
			return FText::FromString("Connecting to EA Servers...");
		FText OutText;
		Online::HasBusyTask(OutText);
		return OutText;
	}

	UFUNCTION(BlueprintPure)
	bool CanCancelBusyTask()
	{
		return Online::CanCancelBusyTask();
	}

	UFUNCTION()
	void CancelBusyTask()
	{
		Online::CancelBusyTask();
	}

	void UpdatePlayerSelectionStatus()
	{
		auto Lobby = Lobby::GetLobby();
		for (int i = 0; i < 2; ++i)
		{
			bool bSelected = false;
			if (Lobby != nullptr)
			{
				for (auto& Member : Lobby.LobbyMembers)
				{
					if (Member.Identity != nullptr && Member.ChosenPlayer == EHazePlayer(i))
						bSelected = true;
				}
			}
			if (bSelected != PrevPlayerSelectionStatus[i])
			{
				OnPlayerSelectionStatusChange.Broadcast(EHazePlayer(i), bSelected);
				PrevPlayerSelectionStatus[i] = bSelected;
			}
		}
	}

	void UpdateMainMenuRichPresence()
	{
		auto Lobby = Lobby::GetLobby();
		if (Lobby != nullptr && Lobby.HasGameStarted())
			return;

		EHazeRichPresence WantedRichPresence = EHazeRichPresence::MainMenu;

		// If we're in an online lobby we should update our rich presence with that
		if (Lobby != nullptr && Lobby.Network != EHazeLobbyNetwork::Local)
			WantedRichPresence = EHazeRichPresence::OnlineLobby;

		// Update presence in main menu if it has changed
		if (WantedRichPresence != AppliedRichPresence)
		{
			Online::UpdateRichPresence(WantedRichPresence);
			AppliedRichPresence = WantedRichPresence;
		}
	}

	void UpdateLevelPreload()
	{
		auto Lobby = Lobby::GetLobby();
		if (Lobby != nullptr
			&& !Lobby.HasGameStarted()
			&& Lobby.LobbyState == EHazeLobbyState::CharacterSelect
			&& CVar_PreloadOnMainMenu.GetInt() != 0
			&& !Game::IsEditorBuild())
		{
			if (!bIsPreloading)
			{
				bIsPreloading = true;
				Progress::PreloadProgressPointFromDisk(Progress::GetProgressPointRefID(Lobby.StartProgressPoint));
			}
		}
		else
		{
			if (bIsPreloading)
			{
				bIsPreloading = false;
				Progress::StopActivePreloadsFromDisk();
			}
		}
	}


	// Modded functions
	UFUNCTION(DevFunction)
	void Show_FPS()
	{
		System::ExecuteConsoleCommand("stat fps");
	}

	UFUNCTION(DevFunction)
	void Show_Volumes()
	{
		System::ExecuteConsoleCommand("show volumes");
	}
};