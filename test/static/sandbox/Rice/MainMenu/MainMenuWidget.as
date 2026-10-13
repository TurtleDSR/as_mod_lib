import Rice.MainMenu.MainMenu;
import Rice.MainMenu.MainOptionsMenu;

event void FOnMainMenuButtonPressed();

const FConsoleVariable CVar_EnableDevMenu("Haze.EnableDevMenu", 0);

class UMainMenuButtonWidget : UHazeUserWidget
{
	default bIsFocusable = true;
	default Visibility = ESlateVisibility::Visible;

	private bool bFocused = false;
	private bool bPressed = false;
	private bool bFocusedByMouse = false;

	UPROPERTY(BlueprintReadWrite)
	bool bCanPlaySound = false;	

	int InternalMouseOverCount = 0;

	UFUNCTION(BlueprintEvent)
	void Narrate()
	{
	}

	UPROPERTY()
	FOnMainMenuButtonPressed OnPressed;

	UFUNCTION(BlueprintPure)
	bool IsHighlighted()
	{
		return bFocused;
	}

	UFUNCTION(BlueprintOverride)
	void OnAddedToFocusPath(FFocusEvent FocusEvent)
	{
		bFocused = true;	
		if(bCanPlaySound)
		{
			if(!bFocusedByMouse)
				GetAudioManager().UI_OnSelectionChanged();
			else
			{
				const float NormalizedInstanceCount = FMath::Clamp(GetAudioManager().MenuWidgetMouseHoverSoundCount / 5.f, 0.f, 1.f);
				UHazeAkComponent::HazeSetGlobalRTPCValue("Rtpc_Menu_ButtonHover_TriggerRate", NormalizedInstanceCount);
				GetAudioManager().UI_OnSelectionChanged_Mouse();

				if(InternalMouseOverCount == 0)
				{
					GetAudioManager().MenuWidgetMouseHoverSoundCount ++;
					InternalMouseOverCount ++;
					System::SetTimer(this, n"ResetMouseOverRTPC", 0.25f, false);
				}
			}
		}
		Narrate();
	}

	UFUNCTION(BlueprintOverride)
	void OnRemovedFromFocusPath(FFocusEvent FocusEvent)
	{
		bFocused = false;
		bFocusedByMouse = false;
	}

	UFUNCTION(BlueprintOverride)
	void OnMouseLeave(FPointerEvent MouseEvent)
	{
		bFocusedByMouse = false;
	}

	UFUNCTION(BlueprintOverride)
	FEventReply OnMouseMove(FGeometry MyGeometry, FPointerEvent MouseEvent)
	{
		if (!bFocused && !MouseEvent.CursorDelta.IsZero())
		{
			bFocusedByMouse = true;
			Widget::SetAllPlayerUIFocus(this);
		}
		return FEventReply::Unhandled();
	}

	UFUNCTION(BlueprintOverride)
	FEventReply OnMouseButtonDown(FGeometry Geom, FPointerEvent Event)
	{
		if (Event.EffectingButton == EKeys::LeftMouseButton)
		{			
			return FEventReply::Handled();
		}
		return FEventReply::Unhandled();
	}

	UFUNCTION(BlueprintOverride)
	FEventReply OnMouseButtonUp(FGeometry Geom, FPointerEvent Event)
	{
		if (Event.EffectingButton == EKeys::LeftMouseButton)
		{
			OnPressed.Broadcast();
			return FEventReply::Handled();
		}
		return FEventReply::Unhandled();
	}

	UFUNCTION(BlueprintOverride)
	FEventReply OnKeyDown(FGeometry Geom, FKeyEvent Event)
	{
		if (Event.Key == EKeys::Enter
			|| Event.Key == EKeys::Virtual_Accept)
		{
			bPressed = true;
			return FEventReply::Handled();
		}
		return FEventReply::Unhandled();
	}

	UFUNCTION(BlueprintOverride)
	FEventReply OnKeyUp(FGeometry Geom, FKeyEvent Event)
	{
		if (Event.Key == EKeys::Enter
			|| Event.Key == EKeys::Virtual_Accept)
		{
			if (bPressed)
				OnPressed.Broadcast();
			return FEventReply::Handled();
		}
		return FEventReply::Unhandled();
	}

	UFUNCTION(BlueprintCallable)
	void ResetForSound()
	{
		System::SetTimer(this, n"ResetCanPlaySound", 0.25f, false);
	}

	UFUNCTION()
	void ResetCanPlaySound()
	{
		bCanPlaySound = true;
	}

	UFUNCTION()
	void ResetMouseOverRTPC()
	{
		GetAudioManager().MenuWidgetMouseHoverSoundCount --;
		InternalMouseOverCount --;
	}

};

class UMainMenuWidget : UMainMenuStateWidget
{
	UPROPERTY(Meta = (BindWidget))
	UWidget EASignInContainer;
	UPROPERTY(Meta = (BindWidget))
	UMenuPromptOrButton EASignInButton;

	private EHazeEntitlement PrevEntitlement = EHazeEntitlement::FullGame;
	private bool bInFriendsPassPopup = false;

	UFUNCTION(BlueprintOverride)
	void Construct()
	{
		EASignInButton.OnPressed.AddUFunction(this, n"OnEASignIn");
	}

	UFUNCTION()
	void OnEASignIn()
	{
		Online::PerformEASignIn();
	}

	UFUNCTION(BlueprintOverride)
	void Show(bool bSnap) override
	{
		PrevEntitlement = Online::GetGameEntitlement();
		Super::Show(bSnap);
		BP_OnEntitlementChange(PrevEntitlement);
	}

	UFUNCTION(BlueprintOverride)
	void Tick(FGeometry MyGeometry, float InDeltaTime)
	{
		auto CurEntitlement = Online::GetGameEntitlement();
		if (CurEntitlement != PrevEntitlement)
		{
			PrevEntitlement = Online::GetGameEntitlement();
			BP_OnEntitlementChange(PrevEntitlement);
		}

		if (Online::ShouldShowRequestEASignIn())
			EASignInContainer.Visibility = ESlateVisibility::SelfHitTestInvisible;
		else
			EASignInContainer.Visibility = ESlateVisibility::Collapsed;
	}

	UFUNCTION()
	void MainMenu_StartLocalGame()
	{
		Lobby::Menu_CreateLocalLobby(MainMenu.OwnerIdentity);
	}

	UFUNCTION()
	void MainMenu_HostOnlineGame()
	{
		Lobby::Menu_CreateHostLobby(MainMenu.OwnerIdentity);
	}

	UFUNCTION()
	void MainMenu_PromptJoin()
	{
		Online::PromptForJoin(MainMenu.OwnerIdentity);
	}

	UFUNCTION()
	void MainMenu_Credits()
	{
		MainMenu.ShowCredits();
	}

	UFUNCTION()
	void MainMenu_OptionsMenu()
	{
		MainMenu.ShowOptionsMenu();
	}

	UFUNCTION()
	void MainMenu_AccessibilityOptions()
	{
		MainMenu.ShowOptionsMenu();

		auto MainOptions = Cast<UMainOptionsMenu>(MainMenu.GetMainMenuWidget(EMainMenuState::Options));
		MainOptions.GetOptionsMenu().GoToTab(0);
		GetAudioManager().UI_OnSelectionConfirmed();
	}

	UFUNCTION()
	void MainMenu_BackToSplash()
	{
		MainMenu.ReturnToSplashScreen(bSnap = false);
		GetAudioManager().UI_ReturnToSplash();
	}

	UFUNCTION()
	void MainMenu_OpenDevMenu()
	{
		Widget::Debug_OpenDevMenu(n"Levels");
	}

	UFUNCTION()
	void MainMenu_Quit()
	{
		Game::QuitGame();
	}

	UFUNCTION(BlueprintPure)
	bool ShouldShowQuitOption() const
	{
		return !Game::IsConsoleBuild();
	}

	UFUNCTION(BlueprintPure)
	bool ShouldShowDevOptions() const
	{
#if TEST
		return true;
#else
		if (Game::HazeGameInstance != nullptr)
		{
			if (Game::HazeGameInstance.IsTrialUpsellNeeded())
				return false;
		}
		return (CVar_EnableDevMenu.GetInt() != 0);
#endif
	}

	UFUNCTION(BlueprintPure)
	bool CanChangeIdentity()
	{
		return Online::RequiresIdentityEngagement()
			&& Game::IsConsoleBuild();
	}

	UFUNCTION(BlueprintOverride)
	FEventReply OnKeyDown(FGeometry Geom, FKeyEvent Event)
	{
		if (MainMenu.IsOwnerInput(Event) && !Event.IsRepeat())
		{
			// Deal with input to the friends pass popup
			if (bInFriendsPassPopup)
			{
				if (Event.Key == EKeys::Enter || Event.Key == EKeys::Virtual_Accept
					|| Event.Key == EKeys::Escape || Event.Key == EKeys::Virtual_Back)
				{
					// Handled in key up
					return FEventReply::Handled();
				}
				else if (Event.Key == EKeys::F1 || Event.Key == EKeys::Gamepad_FaceButton_Left)
				{
					// Handled in key up
					return FEventReply::Handled();
				}
				return Super::OnKeyDown(Geom, Event);
			}

			// Go back to splash when pressing B
			if (Event.Key == EKeys::Escape || Event.Key == EKeys::Virtual_Back)
			{
				MainMenu_BackToSplash();
				return FEventReply::Handled();
			}

			// Switch accounts when pressing Y
			if (Event.Key == EKeys::Gamepad_FaceButton_Top)
			{
				if (Online::ShouldShowRequestEASignIn())
				{
					OnEASignIn();
					return FEventReply::Handled();
				}
				else
				{
					if (CanChangeIdentity())
					{
						Online::SetPrimaryIdentity(nullptr);
						Online::PromptIdentitySignIn(MainMenu.OwnerIdentity, FHazeOnOnlineIdentitySignedIn(this, n"OnIdentitySwitched"));
						return FEventReply::Handled();
					}
				}
			}

			// Accesibility optionst with LB
			if (Event.Key == EKeys::Gamepad_LeftShoulder)
			{
				return FEventReply::Handled();
			}
		}

		return Super::OnKeyDown(Geom, Event);
	}

	UFUNCTION(BlueprintOverride)
	FEventReply OnKeyUp(FGeometry Geom, FKeyEvent Event)
	{
		if (MainMenu.IsOwnerInput(Event) && !Event.IsRepeat())
		{
			// Deal with input to the friends pass popup
			if (bInFriendsPassPopup)
			{
				if (Event.Key == EKeys::Enter || Event.Key == EKeys::Virtual_Accept
					|| Event.Key == EKeys::Escape || Event.Key == EKeys::Virtual_Back)
				{
					HideFriendsPassPopup();
					return FEventReply::Handled();
				}
				else if (Event.Key == EKeys::F1 || Event.Key == EKeys::Gamepad_FaceButton_Left)
				{
					ShowFriendsPassMoreInfo();
					return FEventReply::Handled();
				}

				return Super::OnKeyDown(Geom, Event);
			}

			// Accesibility optionst with LB
			if (Event.Key == EKeys::Gamepad_LeftShoulder)
			{
				MainMenu_AccessibilityOptions();
				return FEventReply::Handled();
			}
		}

		return FEventReply::Unhandled();
	}

	UFUNCTION()
	void OnIdentitySwitched(UHazePlayerIdentity Identity, bool bSuccess)
	{
		if (bSuccess)
			MainMenu.ReturnToSplashScreen(Identity, bSnap = true);
		else
			Online::SetPrimaryIdentity(MainMenu.OwnerIdentity);
	}

	UFUNCTION(BlueprintEvent)
	void BP_OnEntitlementChange(EHazeEntitlement Entitlement) {}

	UFUNCTION()
	void ShowFriendsPassPopup()
	{
		bInFriendsPassPopup = true;
		BP_ShowFriendsPassPopup();
	}

	UFUNCTION()
	void HideFriendsPassPopup()
	{
		bInFriendsPassPopup = false;
		BP_HideFriendsPassPopup();
	}

	UFUNCTION()
	void ShowFriendsPassMoreInfo()
	{
		Online::ShowFriendsPassInfo();
		HideFriendsPassPopup();
	}

	UFUNCTION(BlueprintEvent)
	void BP_ShowFriendsPassPopup() {}

	UFUNCTION(BlueprintEvent)
	void BP_HideFriendsPassPopup() {}
};