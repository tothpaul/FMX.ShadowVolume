program Walk3D;

uses
  System.StartUpCopy,
  FMX.Forms,
  Walk3D.Main in 'Walk3D.Main.pas' {Main},
  Execute.FMX.ShadowVolume in 'Execute.FMX.ShadowVolume.pas',
  Execute.FMX.CubeMan in 'Execute.FMX.CubeMan.pas',
  Execute.FMX.Utils in 'Execute.FMX.Utils.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMain, Main);
  Application.Run;
end.
