import Speed.SpeedSettings;

class USpeedStateComponent : UActorComponent
{
	FTransform SavedTransform;
	FVector SavedVelocity;
	bool bEnabled = SpeedToolsActiveOnLaunch;
}

class USpeedStateSaveCapability : UHazeCapability 
{
	AHazePlayerCharacter Player;
	USpeedStateComponent StateComp;

	default TickGroup = ECapabilityTickGroups::Input;

	UFUNCTION(BlueprintOverride)
	void Setup(FCapabilitySetupParams SetupParams)
	{
		Player = Cast<AHazePlayerCharacter>(Owner);
		StateComp = USpeedStateComponent::GetOrCreate(Player);
	}

	UFUNCTION(BlueprintOverride)
	EHazeNetworkActivation ShouldActivate() const
	{
		if(IsActioning(n"ToggleSpeedtools"))
			return EHazeNetworkActivation::ActivateLocal;

		if (!IsActioning(SaveState1))
			return EHazeNetworkActivation::DontActivate;

		if (!WasActionStarted(SaveState2))
			return EHazeNetworkActivation::DontActivate;

		if (!StateComp.bEnabled)
			return EHazeNetworkActivation::DontActivate;

		return EHazeNetworkActivation::ActivateLocal;
	}

	UFUNCTION(BlueprintOverride)
	EHazeNetworkDeactivation ShouldDeactivate() const
	{
		return EHazeNetworkDeactivation::DeactivateLocal;
	}

	UFUNCTION(BlueprintOverride)
	void OnActivated(FCapabilityActivationParams ActivationParams)
	{
		if(IsActioning(n"ToggleSpeedtools"))
		{
			StateComp.bEnabled = !StateComp.bEnabled;
			return;
		}

		auto MoveComp = UHazeBaseMovementComponent::Get(Owner);
		auto AttachedActor = Player.GetAttachParentActor();
		if (AttachedActor != nullptr)
			StateComp.SavedTransform = AttachedActor.ActorTransform;
		else
			StateComp.SavedTransform = Player.ActorTransform;
		StateComp.SavedVelocity = MoveComp.Velocity;

		ConsumeAction(ActionNames::FindOtherPlayer);
	}
}

class USpeedStateRestoreCapability : UHazeCapability 
{
	AHazePlayerCharacter Player;
	USpeedStateComponent StateComp;

	default TickGroup = ECapabilityTickGroups::Input;

	UFUNCTION(BlueprintOverride)
	void Setup(FCapabilitySetupParams SetupParams)
	{
		Player = Cast<AHazePlayerCharacter>(Owner);
		StateComp = USpeedStateComponent::GetOrCreate(Player);
	}

	UFUNCTION(BlueprintOverride)
	EHazeNetworkActivation ShouldActivate() const
	{
		if (!IsActioning(LoadState1))
			return EHazeNetworkActivation::DontActivate;

		if (!WasActionStarted(LoadState2))
			return EHazeNetworkActivation::DontActivate;

		if (!StateComp.bEnabled)
			return EHazeNetworkActivation::DontActivate;

		return EHazeNetworkActivation::ActivateLocal;
	}

	UFUNCTION(BlueprintOverride)
	EHazeNetworkDeactivation ShouldDeactivate() const
	{
		return EHazeNetworkDeactivation::DeactivateLocal;
	}

	UFUNCTION(BlueprintOverride)
	void OnActivated(FCapabilityActivationParams ActivationParams)
	{
		auto MoveComp = UHazeBaseMovementComponent::Get(Player);
		auto AttachedActor = Player.GetAttachParentActor();
		if (AttachedActor != nullptr)
			AttachedActor.ActorTransform = StateComp.SavedTransform;
		else
			Player.ActorTransform = StateComp.SavedTransform;
		MoveComp.Velocity = StateComp.SavedVelocity;

		ConsumeAction(ActionNames::SwingAttach);
	}
}

class USpeedStateTeleportCapability : UHazeCapability
{
	AHazePlayerCharacter Player;
	AHazePlayerCharacter OtherPlayer;
	USpeedStateComponent StateComp;

	default TickGroup = ECapabilityTickGroups::Input;

	UFUNCTION(BlueprintOverride)
	void Setup(FCapabilitySetupParams SetupParams)
	{
		Player = Cast<AHazePlayerCharacter>(Owner);
		OtherPlayer = Player.OtherPlayer;
		StateComp = USpeedStateComponent::GetOrCreate(Player);
		
	}

	UFUNCTION(BlueprintOverride)
	EHazeNetworkActivation ShouldActivate() const
	{
		if (!IsActioning(TeleportOther1))
			return EHazeNetworkActivation::DontActivate;

		if (!WasActionStarted(TeleportOther2))
			return EHazeNetworkActivation::DontActivate;

		if (!StateComp.bEnabled)
			return EHazeNetworkActivation::DontActivate;

		return EHazeNetworkActivation::ActivateLocal;
	}
	
	UFUNCTION(BlueprintOverride)
	EHazeNetworkDeactivation ShouldDeactivate() const
	{
		return EHazeNetworkDeactivation::DeactivateLocal;
	}

	UFUNCTION(BlueprintOverride)
	void OnActivated(FCapabilityActivationParams ActivationParams)
	{
		
		auto AttachedActor = Player.GetAttachParentActor();
		if (AttachedActor != nullptr)
		{
			auto AttachedOtherActor = OtherPlayer.GetAttachParentActor();
			FTransform Transform;
			
			if (AttachedOtherActor != nullptr)
				Transform = AttachedOtherActor.ActorTransform;
			else
				Transform = OtherPlayer.ActorTransform;

			AttachedActor.ActorTransform = Transform;
		}
		else
			Player.ActorTransform = OtherPlayer.ActorTransform;
			

		ConsumeAction(ActionNames::FindOtherPlayer);
	}
}