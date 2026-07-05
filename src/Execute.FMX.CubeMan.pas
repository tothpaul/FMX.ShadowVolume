unit Execute.FMX.CubeMan;

interface

uses
  System.UITypes,
  System.Math,
  System.Classes,
  System.Math.Vectors,
  FMX.Types3D,
  FMX.Objects3D,
  FMX.Controls3D,
  FMX.MaterialSources,
  FMX.Ani;

const
  BODY_PARTS = 10;

  PART_BODY  = 0;
  PART_HEAD  = 1;
  PART_LARM  = 2;
  PART_LHAND = 3;
  PART_RARM  = 4;
  PART_RHAND = 5;
  PART_LLEG  = 6;
  PART_LFOOT = 7;
  PART_RLEG  = 8;
  PART_RFOOT = 9;

type
  TBoneInfo = record
    StartPoint: TPoint3D;
    EndPoint: TPoint3D;
    Length: Single;
  end;

  TBodyPart = record
    Bone: TDummy;
    Mesh: TCube;
    Tail: TDummy;
    constructor Create(AOwner: TControl3D);
    procedure SetSize(W, H, D: Single);
    function AddNode(const Position: TPoint3D; Rotation: Single): TDummy;
  end;

  TCubeMan = class(TDummy)
  private
    FParts: array[0..BODY_PARTS - 1] of TBodyPart;
    FMaterial: TLightMaterialSource;
    FNeck: TDummy;
    FAnimation: TAnimation;
    procedure DoWalk(Sender: TObject);
    procedure StartAnimation(Animation: TNotifyEvent);
  public
    constructor Create(AOwner: TComponent); override;
    procedure Walk;
  end;

implementation

function AngleTo(const V1, V2: TPoint3D): Single;
begin
  var L := V1.Length * V2.Length;
  if L < 0.001 then
    Result := 0
  else
    Result := ArcCos(V1.DotProduct(V2)/ L);
end;

type
  TControl3DHelper = class helper for TControl3D
    procedure SetMatrix(const M: TMatrix3D);
    procedure AlignDirection(const Direction: TPoint3d);
  end;

procedure TControl3DHelper.SetMatrix(const M: TMatrix3D);
begin
  FLocalMatrix := M;
  RecalcAbsolute;
  RebuildRenderingList;
  Repaint;
end;

procedure TControl3DHelper.AlignDirection(const Direction: TPoint3d);
begin
  var Dir := TControl3D(Parent).AbsoluteToLocal3D(Direction).Normalize;
  var u := TPoint3D.Create(0, -1, 0);
  var w := u.CrossProduct(Dir);
  var d := u.DotProduct(Dir);
  var Q : TQuaternion3D;
  if w.Length < 0.001 then
  begin
    if d < 0 then
      Q := TQuaternion3D.Create(0, 0, PI)
    else
      Q := TQuaternion3D.Identity;
  end else begin
    Q := TQuaternion3D.Create(w.Normalize, ArcCos(d)).Normalize;
  end;
  SetMatrix(Q);
end;

{ TBodyPart }

const
  CubeScale = 1/10;
  DragScale = 1/2;

function TBodyPart.AddNode(const Position: TPoint3D; Rotation: Single): TDummy;
begin
  Result := TDummy.Create(Tail);
  Result.Parent := Bone;
  Result.Position.Point := Position * CubeScale;
  Result.RotationAngle.Z := Rotation;
end;

constructor TBodyPart.Create(AOwner: TControl3D);
begin
  Bone := TDummy.Create(AOwner);
  Bone.Parent := AOwner;
  Mesh := TCube.Create(Bone);
  Mesh.Parent := Bone;
//  Mesh.Opacity := 0.5;
//  Mesh.ZWrite := False;
  Tail := TDummy.Create(Mesh);
  Tail.Parent := Mesh;
end;

procedure TBodyPart.SetSize(W, H, D: Single);
begin
  W := W * CubeScale;
  H := H * CubeScale;
  D := D * CubeScale;
  Mesh.SetSize(W, H, D);
  Mesh.Position.Y := - H / 2;
  Tail.Position.Y := - H / 2;
end;

{ TCubeMan }

constructor TCubeMan.Create(AOwner: TComponent);
begin
  inherited;
  FMaterial := TLightMaterialSource.Create(Self);
  FMaterial.Diffuse := $FFFFFFFF;
  FMaterial.Ambient := $FF202020;
  FMaterial.Emissive := 0;
  FMaterial.Specular := $FF606060;
  FMaterial.Shininess := 30;

  var Hook := TDummy.Create(Self);
  Hook.Parent := Self;
  FParts[PART_BODY].Create(Hook);
  FParts[PART_BODY].Mesh.MaterialSource := FMaterial;
  FParts[PART_BODY].SetSize(15, 17, 10);

  FNeck := TDummy.Create(Self);
  FNeck.Parent := FParts[PART_BODY].Tail;
  FParts[PART_HEAD].Create(FNeck);
  FParts[PART_HEAD].Mesh.MaterialSource := FMaterial;
  FParts[PART_HEAD].SetSize(10, 10, 10);
  FNeck.Position.Y := FParts[PART_HEAD].Mesh.Position.Y - 0.5 * CubeScale;
  FParts[PART_HEAD].Mesh.Position.Y := 0;

  FParts[PART_RARM].Create(FParts[PART_BODY].AddNode(TPoint3D.Create(-15/2, -17, 0), - (90 + 50)));
  FParts[PART_RARM].Mesh.MaterialSource := FMaterial;
  FParts[PART_RARM].SetSize(6, 10, 6);

  FParts[PART_RHAND].Create(FParts[PART_RARM].Tail);
  FParts[PART_RHAND].Mesh.MaterialSource := FMaterial;
  FParts[PART_RHAND].SetSize(6, 10, 6);

  FParts[PART_LARM].Create(FParts[PART_BODY].AddNode(TPoint3D.Create(+15/2, -17,0), + (90 + 50)));
  FParts[PART_LARM].Mesh.MaterialSource := FMaterial;
  FParts[PART_LARM].SetSize(6, 10, 6);

  FParts[PART_LHAND].Create(FParts[PART_LARM].Tail);
  FParts[PART_LHAND].Mesh.MaterialSource := FMaterial;
  FParts[PART_LHAND].SetSize(6, 10, 6);

  FParts[PART_RLEG].Create(FParts[PART_BODY].AddNode(TPoint3D.Create(-15/2 + 6/2, 0, 0), 180));
  FParts[PART_RLEG].Mesh.MaterialSource := FMaterial;
  FParts[PART_RLEG].SetSize(6, 10, 6);

  FParts[PART_RFOOT].Create(FParts[PART_RLEG].Tail);
  FParts[PART_RFOOT].Mesh.MaterialSource := FMaterial;
  FParts[PART_RFOOT].SetSize(6, 10, 6);

  FParts[PART_LLEG].Create(FParts[PART_BODY].AddNode(TPoint3D.Create(+15/2 - 6/2, 0, 0), 180));
  FParts[PART_LLEG].Mesh.MaterialSource := FMaterial;
  FParts[PART_LLEG].SetSize(6, 10, 6);

  FParts[PART_LFOOT].Create(FParts[PART_LLEG].Tail);
  FParts[PART_LFOOT].Mesh.MaterialSource := FMaterial;
  FParts[PART_LFOOT].SetSize(6, 10, 6);
end;

type
  TCustomAnimation = class(TAnimation)
  protected
    procedure ProcessAnimation; override;
  end;

procedure TCustomAnimation.ProcessAnimation;
begin
  // Empty
end;

procedure TCubeMan.DoWalk(Sender: TObject);
begin
  var T := FAnimation.CurrentTime;

  var T1 := 120 * (Abs(T - 1) - 0.5);
  FParts[PART_RLEG].Bone.RotationAngle.X := +T1;
  FParts[PART_LLEG].Bone.RotationAngle.X := -T1;
  FParts[PART_LARM].Bone.RotationAngle.X := +T1;
  FParts[PART_RARM].Bone.RotationAngle.X := -T1;

  if T < 0.6 then
    FParts[PART_LFOOT].Bone.RotationAngle.X := -120 * T/0.6
  else
  if T < 0.8 then
    FParts[PART_LFOOT].Bone.RotationAngle.X := -120 * (0.8 - T - 0.6)/0.2
  else
    FParts[PART_LFOOT].Bone.RotationAngle.X := 0;

  if T < 0.5 then
    FParts[PART_RHAND].Bone.RotationAngle.X := 180 * T
  else
  if T < 1.0 then
    FParts[PART_RHAND].Bone.RotationAngle.X := 180 * (1.0 - T)
  else
  if T < 1.5 then
    FParts[PART_RHAND].Bone.RotationAngle.X := 180 * (T - 1.0)
  else
    FParts[PART_RHAND].Bone.RotationAngle.X := 180 * (2.0 - T);

  T := 2 - T;

  if T < 0.6 then
    FParts[PART_RFOOT].Bone.RotationAngle.X := -120 * T/0.6
  else
  if T < 0.8 then
    FParts[PART_RFOOT].Bone.RotationAngle.X := -120 * (0.8 - T - 0.6)/0.2
  else
    FParts[PART_RFOOT].Bone.RotationAngle.X := 0;

  if T < 0.5 then
    FParts[PART_LHAND].Bone.RotationAngle.X := 180 * T
  else
  if T < 1.0 then
    FParts[PART_LHAND].Bone.RotationAngle.X := 180 * (1.0 - T)
  else
  if T < 1.5 then
    FParts[PART_LHAND].Bone.RotationAngle.X := 180 * (T - 1.0)
  else
    FParts[PART_LHAND].Bone.RotationAngle.X := 180 * (2.0 - T);

end;

procedure TCubeMan.StartAnimation(Animation: TNotifyEvent);
begin
  if FAnimation = nil then
  begin
    FAnimation := TCustomAnimation.Create(Self);
    FAnimation.Parent := Self;
    FAnimation.Duration := 2;
    FAnimation.Loop := True;
  end;
  FAnimation.Stop;
  FAnimation.OnProcess := Animation;
  FAnimation.Start;
end;

procedure TCubeMan.Walk;
begin
  StartAnimation(DoWalk);
end;

end.
