import Peanuts.Audio.HazeAudioManager.AudioManagerStatics;

class USpeedCheckpointComponent : UActorComponent
{
	FString SavedCheckpoint = "";
}

class USpeedSaveCheckpointCapability : UHazeCapability 
{
	AHazePlayerCharacter Player;
	USpeedCheckpointComponent StateComp;
	UHazeAudioManager AudioManager;

	default TickGroup = ECapabilityTickGroups::Input;

	UFUNCTION(BlueprintOverride)
	void Setup(FCapabilitySetupParams SetupParams)
	{
		Player = Cast<AHazePlayerCharacter>(Owner);
		StateComp = USpeedCheckpointComponent::GetOrCreate(Player);
		AudioManager = GetAudioManager();
	}

	UFUNCTION(BlueprintOverride)
	EHazeNetworkActivation ShouldActivate() const
	{
		if (IsActioning(n"SaveCheckpoint"))
			return EHazeNetworkActivation::ActivateLocal;

		return EHazeNetworkActivation::DontActivate;
	}

	UFUNCTION(BlueprintOverride)
	EHazeNetworkDeactivation ShouldDeactivate() const
	{
		return EHazeNetworkDeactivation::DeactivateLocal;
	}

	UFUNCTION(BlueprintOverride)
	void OnActivated(FCapabilityActivationParams ActivationParams)
	{
		StateComp.SavedCheckpoint = AudioManager.CurrentInLevel + "##" + AudioManager.CurrentCheckpointName;	
	}

	UFUNCTION(BlueprintOverride)
	FString GetDebugString() const
	{
		FString Str;
		/*
		Str += "Current Level Group: ";
		Str += AudioManager.CurrentLevelGroup;
		Str += "\n";
		Str += "Current Level: ";
		Str += AudioManager.CurrentInLevel;
		Str += "\n";
		Str += "Current Checkpoint Name: ";
		Str += AudioManager.CurrentCheckpointName;
		Str += "\n\n";

		Str += "Saved Progress Point: ";
		Str += StateComp.SavedCheckpoint;
		Str += "\n";
		*/

        return Str;
	}

}

class USpeedLoadCheckpointCapability : UHazeCapability 
{
	AHazePlayerCharacter Player;
	USpeedCheckpointComponent StateComp;

	default TickGroup = ECapabilityTickGroups::Input;

	UFUNCTION(BlueprintOverride)
	void Setup(FCapabilitySetupParams SetupParams)
	{
		Player = Cast<AHazePlayerCharacter>(Owner);
		StateComp = USpeedCheckpointComponent::GetOrCreate(Player);
	}

	UFUNCTION(BlueprintOverride)
	EHazeNetworkActivation ShouldActivate() const
	{
		if (IsActioning(n"LoadCheckpoint"))
			return EHazeNetworkActivation::ActivateLocal;

		return EHazeNetworkActivation::DontActivate;
	}

	UFUNCTION(BlueprintOverride)
	EHazeNetworkDeactivation ShouldDeactivate() const
	{
		return EHazeNetworkDeactivation::DeactivateLocal;
	}

	UFUNCTION(BlueprintOverride)
	void OnActivated(FCapabilityActivationParams ActivationParams)
	{
		if (StateComp.SavedCheckpoint != "")
			Progress::RestartFromProgressPoint(StateComp.SavedCheckpoint, false);
	}
}

