unit Walk3D.Main;

interface
{.$DEFINE SHOW_RAYS}
uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Viewport3D,
  System.Math.Vectors, FMX.Types3D, FMX.MaterialSources, FMX.Objects3D,
  FMX.Controls3D, FMX.Ani,
  Execute.FMX.CubeMan,
  Execute.FMX.ShadowVolume;

type
  TDummy = class(FMX.Objects3D.TDummy)
    procedure RenderHelper; override;
    procedure RenderChildren; override;
  end;

  TMain = class(TForm)
    Viewport3D1: TViewport3D;
    Dummy1: TDummy;
    Light1: TLight;
    Plane1: TPlane;
    LightMaterialSource1: TLightMaterialSource;
    Cube1: TCube;
    LightMaterialSource2: TLightMaterialSource;
    FloatAnimation1: TFloatAnimation;
    Cube2: TCube;
    FloatAnimation3: TFloatAnimation;
    FloatAnimation4: TFloatAnimation;
    FloatAnimation5: TFloatAnimation;
    Light2: TLight;
    Cube3: TCube;
    FloatAnimation2: TFloatAnimation;
    Cube4: TCube;
    Dummy2: TDummy;
    FloatAnimation6: TFloatAnimation;
    Dummy3: TDummy;
    Mesh1: TMesh;
    Dummy4: TDummy;
    FloatAnimation7: TFloatAnimation;
    LightMaterialSource3: TLightMaterialSource;
    procedure Dummy1Render(Sender: TObject; Context: TContext3D);
    procedure FormCreate(Sender: TObject);
  private
    { Déclarations privées }
    ShadowVolume: TShadowVolume;
    CubeMan: TCubeMan;
  public
    { Déclarations publiques }
  end;

var
  Main: TMain;

implementation

{$R *.fmx}

{ TDummy }

procedure TDummy.RenderHelper;
begin
  // do nothing
  if Assigned(OnRender) then
    Context.PushContextStates;
end;

procedure TDummy.RenderChildren;
begin
  inherited;
  if Assigned(OnRender) then
  begin
    Context.PopContextStates;
    OnRender(Self, Context);
  end;
end;

{ TForm1 }

procedure TMain.Dummy1Render(Sender: TObject; Context: TContext3D);
begin
//  ShadowVolume.ShowRays(Context, Light1, Cube1);
//  ShadowVolume.ShowRays(Context, Light2, Cube1);
//  ShadowVolume.ShowRays(Context, Light2, Cube4);

  ShadowVolume.RenderShadows(Dummy1, Context, Light1);
  ShadowVolume.RenderShadows(Dummy1, Context, Light2);

end;

procedure TMain.FormCreate(Sender: TObject);
begin
  CubeMan := TCubeMan.Create(Self);
  CubeMan.Parent := Dummy3;
  CubeMan.Position.Y := -2;
  CubeMan.Position.Z := -8;
  CubeMan.RotationAngle.Y := 80;
  CubeMan.Walk;
end;

end.
