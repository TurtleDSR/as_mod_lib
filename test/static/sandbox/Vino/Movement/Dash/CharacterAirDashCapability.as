import Vino.Movement.Capabilities.Standard.CharacterMovementCapability;
import Vino.Movement.Dash.CharacterDashSettings;
import Vino.Movement.Dash.CharacterDashComponent;
import Vino.Movement.Jump.AirJumpsComponent;
import Vino.Movement.Capabilities.WallSlide.WallSlideNames;
import Rice.Math.MathStatics;

class UCharacterAirDashCapability : UCharacterMovementCapability
{	
	default RespondToEvent(MovementActivationEvents::Airbourne);

	default CapabilityTags.Add(MovementSystemTags::GroundMovement);
	default CapabilityTags.Add(CapabilityTags::Movement);
	default CapabilityTags.Add(CapabilityTags::MovementInput);
	default CapabilityTags.Add(CapabilityTags::MovementAction);	
	default CapabilityTags.Add(CapabilityTags::GameplayAction);
	default CapabilityTags.Add(MovementSystemTags::Dash);
	default CapabilityTags.Add(MovementSystemTags::AirDash);
	default CapabilityTags.Add(n"DashAction");
	
	default TickGroup = ECapabilityTickGroups::ActionMovement;
	default TickGroupOrder = 140;
	default SeperateInactiveTick(ECapabilityTickGroups::ActionMovement, 107);

	default CapabilityDebugCategory = CapabilityTags::Movement;

	AHazePlayerCharacter Player;
	UCharacterDashComponent DashComp;
	UCharacterAirJumpsComponent AirJumpsComp;
	UCharacterAirDashSettings AirDashSettings;

	// Calculated on activate using distance over duration
	float Deceleration = 0.f;

	float DurationAlpha;

	UFUNCTION(BlueprintOverride)
	void Setup(FCapabilitySetupParams SetupParams)
	{
		Super::Setup(SetupParams);
		Player = Cast<AHazePlayerCharacter>(Owner);
		DashComp = UCharacterDashComponent::GetOrCreate(Owner);
		AirJumpsComp = UCharacterAirJumpsComponent::GetOrCreate(Owner);		
		AirDashSettings = UCharacterAirDashSettings::GetSettings(Owner);
	}

	UFUNCTION(BlueprintOverride)
	EHazeNetworkActivation ShouldActivate_EventBased() const
	{
		if (!MoveComp.CanCalculateMovement())
       		return EHazeNetworkActivation::DontActivate;

		if (MoveComp.IsGrounded())
       		return EHazeNetworkActivation::DontActivate;
		
		if (!WasActionStarted(ActionNames::MovementDash))
       		return EHazeNetworkActivation::DontActivate;

		if (!AirJumpsComp.CanDash())
       		return EHazeNetworkActivation::DontActivate;

		if (DeactiveDuration < AirDashSettings.Cooldown)
			return EHazeNetworkActivation::DontActivate;

        return EHazeNetworkActivation::ActivateUsingCrumb;
	}

	UFUNCTION(BlueprintOverride)
	EHazeNetworkDeactivation ShouldDeactivate() const
	{
		if (!MoveComp.CanCalculateMovement())
			return RemoteLocalControlCrumbDeactivation();
       		
		if (ActiveDuration >= AirDashSettings.Duration)
       		return EHazeNetworkDeactivation::DeactivateUsingCrumb;

		if (MoveComp.IsGrounded())
       		return EHazeNetworkDeactivation::DeactivateUsingCrumb;

		return EHazeNetworkDeactivation::DontDeactivate;
	}

	UFUNCTION(BlueprintOverride)
	void OnActivated(FCapabilityActivationParams ActivationParams)
	{
		Player.BlockCapabilities(ActionNames::WeaponAim, this);
		Player.SetCapabilityActionState(DashTags::AirDashing, EHazeActionState::Active);

		if (ActivationParams.IsStale())
			return;

		Player.ApplyPivotLagSpeed(FVector(0.5f, 0.5f, 0.f), this, EHazeCameraPriority::Low);
		Player.ApplyPivotLagMax(FVector(200.f, 200.f, 800.f), this, EHazeCameraPriority::Low);

		FVector MoveDirection = GetAttributeVector(AttributeVectorNames::MovementDirection);
		if (MoveDirection.IsNearlyZero())
			MoveDirection = Owner.ActorForwardVector;
		MoveDirection.Normalize();

		FVector HorizontalVelocity = MoveDirection * AirDashSettings.StartSpeed + MoveComp.JumpOffInheritedHorizontalVelocity;
		FVector VerticalVelocity = MoveComp.WorldUp * AirDashSettings.StartUpwardsSpeed + MoveComp.JumpOffInheritedVerticalVelocity;
        MoveComp.SetVelocity(HorizontalVelocity + VerticalVelocity);

		Deceleration = (AirDashSettings.EndSpeed - AirDashSettings.StartSpeed) / AirDashSettings.Duration;
		DurationAlpha = 0.f;

		AirJumpsComp.ConsumeDash();
	}

	UFUNCTION(BlueprintOverride)
	void OnDeactivated(FCapabilityDeactivationParams DeactivationParams)
	{
		Player.UnblockCapabilities(ActionNames::WeaponAim, this);
		Player.SetCapabilityActionState(DashTags::AirDashing, EHazeActionState::Inactive);

		DashComp.DashActiveDuration = 0.f;
		Player.ClearSettingsByInstigator(this);
		Player.ClearCameraSettingsByInstigator(this);
	}

	UFUNCTION(BlueprintOverride)
	void TickActive(float DeltaTime)
	{	
		DashComp.DashActiveDuration += DeltaTime;

		FHazeFrameMovement FrameMove = MoveComp.MakeFrameMovement(n"AirDash");
		CalculateFrameMove(FrameMove, DeltaTime);
		MoveCharacter(FrameMove, n"AirDash");
		
		CrumbComp.LeaveMovementCrumb();	
	}	

	void CalculateFrameMove(FHazeFrameMovement& FrameMove, float DeltaTime)
	{	
		if (HasControl())
		{	
			DurationAlpha = Math::Saturate(ActiveDuration / AirDashSettings.Duration);

			FVector Velocity = MoveComp.Velocity.ConstrainToPlane(MoveComp.WorldUp);

			FVector MoveDirection = GetAttributeVector(AttributeVectorNames::MovementDirection);
			if (MoveDirection.IsNearlyZero())
				MoveDirection = Owner.ActorForwardVector;
			MoveDirection.Normalize();

			FVector HorizontalVelocity = MoveComp.Velocity.ConstrainToPlane(MoveComp.WorldUp);
			FVector TargetVelocity = MoveDirection * HorizontalVelocity.Size();

			 if (ActiveDuration <= 0.08f)
			 	Velocity = TargetVelocity;
			else
				Velocity = FMath::Lerp(Velocity, TargetVelocity, (ActiveDuration / AirDashSettings.Duration) * 0.125f);

			Velocity += Velocity.GetSafeNormal() * Deceleration * DeltaTime;

			FrameMove.ApplyVelocity(Velocity);
			FrameMove.ApplyActorVerticalVelocity();
			FrameMove.ApplyAndConsumeImpulses();

			float GravityMultiplier = FMath::Pow(DurationAlpha, AirDashSettings.GravityPow);
			FrameMove.ApplyVelocity(MoveComp.Gravity * GravityMultiplier * DeltaTime);

			FVector TargetFaceDirection = MoveComp.OwnerRotation.ForwardVector;
			if (MoveComp.HorizontalVelocity > 50.f)
				TargetFaceDirection = MoveComp.Velocity.SafeNormal;
				
			if (MoveComp.ForwardHit.bBlockingHit)
				TargetFaceDirection = TargetVelocity.SafeNormal;

			if (ActiveDuration <= 0.08f)
				MoveComp.SetTargetFacingDirection(TargetFaceDirection);
			else
				MoveComp.SetTargetFacingDirection(TargetFaceDirection, 2.f);


			FrameMove.OverrideStepDownHeight(5.f);	
			FrameMove.FlagToMoveWithDownImpact();
			FrameMove.ApplyTargetRotationDelta(); 
		}
		else
		{
			FHazeActorReplicationFinalized ConsumedParams;
			CrumbComp.ConsumeCrumbTrailMovement(DeltaTime, ConsumedParams);
			FrameMove.ApplyConsumedCrumbData(ConsumedParams);
		}
		
	}

	float GetDashSpeed(float DeltaTime)
	{
		float SpeedAlpha = FMath::Pow(DurationAlpha, AirDashSettings.SpeedPow);
		float OldSpeed = FMath::Lerp(AirDashSettings.StartSpeed, AirDashSettings.EndSpeed, SpeedAlpha);		

		return OldSpeed;
	}
}
