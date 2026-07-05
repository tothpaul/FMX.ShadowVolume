unit Execute.FMX.ShadowVolume;

{

  Delphi FMX ShadowVolume (c)2026 by Execute SARL
  https://

}

interface
// debug purpose
{.$DEFINE SHOW_RAYS}
{.$DEFINE SHOW_VOLUME}
// Z-PASS or Z-FAIL Shadow Volume
{$DEFINE Z_FAIL}
uses
  System.UITypes,
  System.Math.Vectors,
  FMX.Types,
  FMX.Types3D,
  FMX.Objects3D,
  FMX.Controls3D;

type
  TShadowVolume = record
  private const
    VERTEX_PER_FACE = 4;
    MAX_EDGE_COUNT  = 6;
    INDICES_PER_FACE = 6;
   {$IFDEF Z_FAIL}
    MAX_CAP_FACES = 2 * 5;
   {$ENDIF}
  private
    Context: TContext3D;
    Light: TLight;
    LightPos: TPoint3D;
    Cube: TCube;
    CubeSize: TMatrix3D;
    LightSource: TPoint3D;
    ShadowVertices: TVertexDeclaration;
    ShadowPointsArray: array[0..(MAX_EDGE_COUNT * VERTEX_PER_FACE {$IFDEF Z_FAIL}+ MAX_CAP_FACES * VERTEX_PER_FACE{$ENDIF}) - 1] of TPoint3D;
    ShadowPointsCount: Integer;
    ShadowIndicesArray: array[0..(MAX_EDGE_COUNT * INDICES_PER_FACE {$IFDEF Z_FAIL}+ MAX_CAP_FACES * INDICES_PER_FACE{$ENDIF}) - 1] of Integer;
    ShadowIndicesCount: Integer;
    procedure RenderCubes(Parent: TFmxObject);
    procedure ProjectCube(Cube: TCube);
    procedure SetLightSource();
  {$IFDEF Z_FAIL}
    procedure AddFace(Index: Integer);
  {$ENDIF}
    procedure AddShadow(A, B: TPoint3D);
    procedure DrawRays();
    procedure DrawLines();
    procedure RenderShadow();
  public
    procedure RenderShadows(Root:TControl3D; Context: TContext3D; Light: TLight);
    procedure ShowRays(Context: TContext3D; Light: TLight; Cube: TCube);
    procedure Project(Cube: TCube; Light: TLight; Data: TMeshData);
  end;

implementation

const
  FAR_DIST = 1;
  STENCIL_ZERO = {$IFDEF Z_FAIL}128{$ELSE}0{$ENDIF};

  {
         4----5
         |\   :\
         | 0----1
   LEFT  7.|. 6 |  RIGHT
          \|   .|
           3----2
  }

  FACE_NORMALS: array[0..5] of TPoint3D = (
    (X: 0; Y: 0; Z:-1), // FRONT
    (X: 0; Y: 0; Z:+1), // BACK
    (X: 0; Y: 1; Z: 0), // BOTTOM
    (X: 0; Y:-1; Z: 0), // TOP
    (X: 1; Y: 0; Z: 0), // RIGHT
    (X:-1; Y: 0; Z: 0)  // LEFT
  );

  CUBE_VERTICES: array[0..7] of TPoint3D = (
    (X:-0.5; Y:-0.5; Z:-0.5),
    (X:+0.5; Y:-0.5; Z:-0.5),
    (X:+0.5; Y:+0.5; Z:-0.5),
    (X:-0.5; Y:+0.5; Z:-0.5),
    (X:-0.5; Y:-0.5; Z:+0.5),
    (X:+0.5; Y:-0.5; Z:+0.5),
    (X:+0.5; Y:+0.5; Z:+0.5),
    (X:-0.5; Y:+0.5; Z:+0.5)
  );

  CUBE_INDICES: array[0..5, 0..3] of Integer = (
    (0, 1, 2, 3), // FRONT
    (5, 4, 7, 6), // BACK
    (3, 2, 6, 7), // BOTTOM
    (4, 5, 1, 0), // TOP
    (1, 5, 6, 2), // RIGHT
    (4, 0, 3, 7)  // LEFT
  );

procedure TShadowVolume.RenderShadows(Root: TControl3D; Context: TContext3D; Light: TLight);
begin
  Self.Context := Context;
  Self.Light := Light;

  with Light.AbsolutePosition do
    LightPos := TPoint3D.Create(X, Y, Z);

  SetLength(ShadowVertices, 1);
  ShadowVertices[0].Format := TVertexFormat.Vertex;
  ShadowVertices[0].Offset := 0;

{$IFNDEF SHOW_RAYS}
  Context.PushContextStates;

  Context.Clear([TClearTarget.Stencil], 0, 0, STENCIL_ZERO);
  Context.SetContextState(TContextState.csStencilOn);
  Context.SetStencilFunc(TStencilFunc.Always, 0, $FF);
  Context.SetContextState(TContextState.csZWriteOff);
{$IFNDEF SHOW_VOLUME}
  Context.SetContextState(TContextState.csColorWriteOff);
{$ENDIF}
{$ENDIF}

  RenderCubes(Root);

{$IFNDEF SHOW_RAYS}
  Context.SetContextState(TContextState.csColorWriteOn);
  Context.SetContextState(TContextState.csZTestOff);
  Context.SetContextState(TContextState.csFrontFace);
  Context.SetStencilFunc(TStencilFunc.NotEqual, STENCIL_ZERO, $FF);
  Context.SetContextState(TContextState.cs2DScene);
  Context.SetMatrix(TMatrix3D.Identity);
  var P := TPoint3D.Create(Context.Width, Context.Height, 0);
  Context.FillRect(TPoint3D.Zero, P, 0.25, TAlphaColors.Black);

  Context.SetContextState(TContextState.cs3DScene);
  Context.SetContextState(TContextState.csZTestOn);
  Context.SetContextState(TContextState.csZWriteOn);
  Context.SetContextState(TContextState.csStencilOff);

  Context.PopContextStates;
{$ENDIF}
end;

procedure TShadowVolume.ShowRays(Context: TContext3D; Light: TLight; Cube: TCube);
begin
  Self.Context := Context;
  Self.Light := Light;

  with Light.AbsolutePosition do
    LightPos := TPoint3D.Create(X, Y, Z);

  Self.Cube := Cube;
  CubeSize := TMatrix3D.CreateScaling(TPoint3D.Create(Cube.Width, Cube.Height, Cube.Depth));
  SetLightSource();
  DrawRays();
end;

procedure TShadowVolume.RenderCubes(Parent: TFmxObject);
begin
  for var I := 0 to Parent.ChildrenCount - 1 do
  begin
    var Child := Parent.Children[I];
    if Child is TCube then
      ProjectCube(TCube(Child));
    RenderCubes(Child);
  end;
end;

procedure TShadowVolume.Project(Cube: TCube; Light: TLight; Data: TMeshData);
begin
  Self.Cube := TCube(Cube);
  CubeSize := TMatrix3D.CreateScaling(TPoint3D.Create(Cube.Width, Cube.Height, Cube.Depth));
  SetLightSource();
  Data.VertexBuffer.Length := ShadowPointsCount;
  Data.IndexBuffer.Length := ShadowIndicesCount;
  for var i := 0 to ShadowPointsCount - 1 do
  begin
    Data.VertexBuffer.Vertices[i] := ShadowPointsArray[i];
  end;
  for var i := 0 to ShadowIndicesCount - 1 do
  begin
    Data.IndexBuffer[i] := ShadowIndicesArray[i];
  end;
  Data.CalcFaceNormals(True);
end;

procedure TShadowVolume.ProjectCube(Cube: TCube);
begin
  Self.Cube := Cube;
  CubeSize := TMatrix3D.CreateScaling(TPoint3D.Create(Cube.Width, Cube.Height, Cube.Depth));

  SetLightSource();

// DEBUG Purpose
{$IFDEF SHOW_RAYS}
//  DrawRays();
  DrawLines();
//  RenderShadow();
{$ELSE}

  Context.SetContextState(TContextState.csFrontFace);
{$IFDEF Z_FAIL}
  Context.SetStencilOp(TStencilOp.Increase, TStencilOp.Increase, TStencilOp.Keep);
{$ELSE}
  Context.SetStencilOp(TStencilOp.Keep, TStencilOp.Keep, TStencilOp.Increase);
{$ENDIF}
  RenderShadow();

  Context.SetContextState(TContextState.csBackFace);
{$IFDEF Z_FAIL}
  Context.SetStencilOp(TStencilOp.Decrease, TStencilOp.Decrease, TStencilOp.Keep);
{$ELSE}
  Context.SetStencilOp(TStencilOp.Keep, TStencilOp.Keep, TStencilOp.Decrease);
{$ENDIF}
  RenderShadow();

{$ENDIF}
end;

procedure TShadowVolume.SetLightSource();
const
  FRONT  = 0;
  BACK   = 1;
  BOTTOM = 2;
  TOP    = 3;
  RIGHT  = 4;
  LEFT   = 5;
var
  Dots: array[0..5] of Boolean;
begin
  LightSource := Cube.AbsoluteToLocal3D(LightPos);

  for var I := 0 to 5 do
  begin
    var FaceCenter := FACE_NORMALS[I] * 0.5 * CubeSize;
    var LightVector := (LightSource - FaceCenter);
    Dots[I] := FACE_NORMALS[I].DotProduct(LightVector) > 0.0001;
  end;

  ShadowPointsCount := 0;
  ShadowIndicesCount := 0;

  if Dots[FRONT] then
  begin
    if not Dots[TOP] then
      AddShadow(CUBE_VERTICES[0], CUBE_VERTICES[1]);
    if not Dots[BOTTOM] then
      AddShadow(CUBE_VERTICES[2], CUBE_VERTICES[3]);
    if not Dots[LEFT] then
      AddShadow(CUBE_VERTICES[3], CUBE_VERTICES[0]);
    if not Dots[RIGHT] then
      AddShadow(CUBE_VERTICES[1], CUBE_VERTICES[2]);
  {$IFDEF Z_FAIL}
  end else begin
    AddFace(FRONT);
  {$ENDIF}
  end;

  if Dots[BACK] then
  begin
    if not Dots[TOP] then
      AddShadow(CUBE_VERTICES[5], CUBE_VERTICES[4]);
    if not Dots[BOTTOM] then
      AddShadow(CUBE_VERTICES[7], CUBE_VERTICES[6]);
    if not Dots[LEFT] then
      AddShadow(CUBE_VERTICES[4], CUBE_VERTICES[7]);
    if not Dots[RIGHT] then
      AddShadow(CUBE_VERTICES[6], CUBE_VERTICES[5]);
  {$IFDEF Z_FAIL}
  end else begin
    AddFace(BACK);
  {$ENDIF}
  end;

  if Dots[TOP] then
  begin
    if not Dots[FRONT] then
      AddShadow(CUBE_VERTICES[1], CUBE_VERTICES[0]);
    if not Dots[BACK] then
      AddShadow(CUBE_VERTICES[4], CUBE_VERTICES[5]);
    if not Dots[RIGHT] then
      AddShadow(CUBE_VERTICES[5], CUBE_VERTICES[1]);
    if not Dots[LEFT] then
      AddShadow(CUBE_VERTICES[0], CUBE_VERTICES[4]);
  {$IFDEF Z_FAIL}
   end else begin
    AddFace(TOP);
  {$ENDIF}
  end;

  if Dots[BOTTOM] then
  begin
    if not Dots[FRONT] then
      AddShadow(CUBE_VERTICES[3], CUBE_VERTICES[2]);
    if not Dots[BACK] then
      AddShadow(CUBE_VERTICES[6], CUBE_VERTICES[7]);
    if not Dots[RIGHT] then
      AddShadow(CUBE_VERTICES[2], CUBE_VERTICES[6]);
    if not Dots[LEFT] then
      AddShadow(CUBE_VERTICES[7], CUBE_VERTICES[3]);
  {$IFDEF Z_FAIL}
  end else begin
    AddFace(BOTTOM);
  {$ENDIF}
  end;

  if Dots[LEFT] then
  begin
    if not Dots[FRONT] then
      AddShadow(CUBE_VERTICES[0], CUBE_VERTICES[3]);
    if not Dots[BACK] then
      AddShadow(CUBE_VERTICES[7], CUBE_VERTICES[4]);
    if not Dots[TOP] then
      AddShadow(CUBE_VERTICES[4], CUBE_VERTICES[0]);
    if not Dots[BOTTOM] then
      AddShadow(CUBE_VERTICES[3], CUBE_VERTICES[7]);
  {$IFDEF Z_FAIL}
  end else begin
    AddFace(LEFT);
  {$ENDIF}
  end;

  if Dots[RIGHT] then
  begin
    if not Dots[FRONT] then
      AddShadow(CUBE_VERTICES[2], CUBE_VERTICES[1]);
    if not Dots[BACK] then
      AddShadow(CUBE_VERTICES[5], CUBE_VERTICES[6]);
    if not Dots[TOP] then
      AddShadow(CUBE_VERTICES[1], CUBE_VERTICES[5]);
    if not Dots[BOTTOM] then
      AddShadow(CUBE_VERTICES[6], CUBE_VERTICES[2]);
  {$IFDEF Z_FAIL}
  end else begin
    AddFace(RIGHT);
  {$ENDIF}
  end;
end;

{$IFDEF Z_FAIL}
procedure TShadowVolume.AddFace(Index: Integer);
begin
  ShadowIndicesArray[ShadowIndicesCount + 0] := ShadowPointsCount;
  ShadowIndicesArray[ShadowIndicesCount + 1] := ShadowPointsCount + 3;
  ShadowIndicesArray[ShadowIndicesCount + 2] := ShadowPointsCount + 1;
  ShadowIndicesArray[ShadowIndicesCount + 3] := ShadowPointsCount + 3;
  ShadowIndicesArray[ShadowIndicesCount + 4] := ShadowPointsCount + 2;
  ShadowIndicesArray[ShadowIndicesCount + 5] := ShadowPointsCount + 1;
  Inc(ShadowIndicesCount, 6);

  for var i := 0 to 3 do
  begin
    ShadowPointsArray[ShadowPointsCount] := CUBE_VERTICES[CUBE_INDICES[Index, i]] * CubeSize;
    Inc(ShadowPointsCount);
  end;

  ShadowIndicesArray[ShadowIndicesCount + 0] := ShadowPointsCount;
  ShadowIndicesArray[ShadowIndicesCount + 1] := ShadowPointsCount + 1;
  ShadowIndicesArray[ShadowIndicesCount + 2] := ShadowPointsCount + 3;
  ShadowIndicesArray[ShadowIndicesCount + 3] := ShadowPointsCount + 3;
  ShadowIndicesArray[ShadowIndicesCount + 4] := ShadowPointsCount + 1;
  ShadowIndicesArray[ShadowIndicesCount + 5] := ShadowPointsCount + 2;
  Inc(ShadowIndicesCount, 6);

  for var i := 0 to 3 do
  begin
    var A := CUBE_VERTICES[CUBE_INDICES[Index, i]] * CubeSize;
    ShadowPointsArray[ShadowPointsCount] := A + (A - LightSource) * FAR_DIST;
    Inc(ShadowPointsCount);
  end;
end;
{$ENDIF}

procedure TShadowVolume.AddShadow(A, B: TPoint3D);
begin
  A := A * CubeSize;
  B := B * CubeSize;

  ShadowIndicesArray[ShadowIndicesCount + 0] := ShadowPointsCount;
  ShadowIndicesArray[ShadowIndicesCount + 1] := ShadowPointsCount + 1;
  ShadowIndicesArray[ShadowIndicesCount + 2] := ShadowPointsCount + 2;
  ShadowIndicesArray[ShadowIndicesCount + 3] := ShadowPointsCount + 2;
  ShadowIndicesArray[ShadowIndicesCount + 4] := ShadowPointsCount + 1;
  ShadowIndicesArray[ShadowIndicesCount + 5] := ShadowPointsCount + 3;
  Inc(ShadowIndicesCount, 6);

  ShadowPointsArray[ShadowPointsCount + 0] := A;
  ShadowPointsArray[ShadowPointsCount + 1] := A + (A - LightSource) * FAR_DIST;
  ShadowPointsArray[ShadowPointsCount + 2] := B;
  ShadowPointsArray[ShadowPointsCount + 3] := B + (B - LightSource) * FAR_DIST;

  Inc(ShadowPointsCount, 4);
end;

procedure TShadowVolume.DrawRays;
begin
  Context.PushContextStates;
  Context.SetMatrix(Cube.AbsoluteMatrix);
  var I : Integer := 0;
  while I < ShadowPointsCount do
  begin
    Context.DrawLine(
      LightSource,
      ShadowPointsArray[I + 0],
      1,
      TAlphaColors.Red
    );
    Context.DrawLine(
      ShadowPointsArray[I + 0],
      ShadowPointsArray[I + 1],
      1,
      TAlphaColors.Cornflowerblue
    );
    Inc(I, 2);
  end;
  Context.PopContextStates;
end;

procedure TShadowVolume.DrawLines;
begin
  Context.PushContextStates;
  Context.SetMatrix(Cube.AbsoluteMatrix);
  var I : Integer := 0;

  while I < ShadowPointsCount do
  begin
    Context.DrawLine(
      ShadowPointsArray[I + 0],
      ShadowPointsArray[I + 1],
      1,
      TAlphaColors.Red
    );
    Context.DrawLine(
      ShadowPointsArray[I + 1],
      ShadowPointsArray[I + 2],
      1,
      TAlphaColors.Red
    );
    Context.DrawLine(
      ShadowPointsArray[I + 2],
      ShadowPointsArray[I + 3],
      1,
      TAlphaColors.Red
    );
    Context.DrawLine(
      ShadowPointsArray[I + 3],
      ShadowPointsArray[I + 0],
      1,
      TAlphaColors.Red
    );
    Inc(I, 4);
  end;

  Context.PopContextStates;
end;

procedure TShadowVolume.RenderShadow;
begin
  if ShadowPointsCount > 0 then
  begin
    Context.PushContextStates;
    Context.SetMatrix(Cube.AbsoluteMatrix);
    Context.DrawPrimitives(
      TPrimitivesKind.Triangles,
      @ShadowPointsArray,
      @ShadowIndicesArray,
      ShadowVertices,
      SizeOf(TPoint3D),
      ShadowPointsCount,
      SizeOf(Integer),
      ShadowIndicesCount,
      nil,
      1
    );
    Context.PopContextStates;
  end;
end;

end.
