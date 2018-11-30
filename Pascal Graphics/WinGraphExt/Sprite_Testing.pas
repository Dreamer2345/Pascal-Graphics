program SpriteTesting;
{$APPTYPE GUI}

uses wingraph,wincrt,sysutils,math;

const
	ScrZoom = 3;
	StepX = 32;
	StepY = 32;
	BlockWidth = 16;
	BlockHeight = 16;
	ScrDefX = ScrZoom*BlockWidth;
	ScrDefY = ScrZoom*BlockHeight;
	ScrWidth = 10;
	ScrHeight = 10;
	WindowW = ScrDefX*ScrWidth;
	WindowH = ScrDefY*ScrHeight;
	WindowCenterX = Trunc(WindowW/2);
	WindowCenterY = Trunc(WindowH/2);
	CenterX = Trunc(ScrWidth/2)+1;
	CenterY = Trunc(ScrHeight/2)+1;
	DefaultID = 9;
	Noise : array[0..256] of byte = (250,206,156,7,23,218,30,2,211,190,88,109,166,0,221,106,11,122,193,234,175,155,205,216,212,204,200,131,152,199,41,189,173,154,227,228,31,29,220,151,215,179,128,244,194,235,73,183,164,6,148,8,253,196,63,94,168,159,83,82,239,110,178,192,170,182,191,141,181,56,18,17,124,248,115,14,70,203,233,97,62,251,243,139,117,161,213,103,107,169,230,195,40,143,121,44,157,45,46,9,71,142,209,96,28,108,3,78,207,37,136,184,79,50,98,69,12,111,123,36,177,255,24,87,245,61,81,214,145,54,13,59,125,114,224,93,53,48,102,22,104,252,92,237,150,112,127,64,89,185,25,232,86,165,229,162,52,198,118,144,51,60,241,126,65,57,19,99,16,95,238,67,140,21,171,91,34,85,58,84,90,47,113,15,226,147,137,116,167,174,75,149,35,39,26,223,176,42,246,231,20,120,158,134,197,33,247,242,240,172,217,222,135,254,132,219,202,74,27,32,55,153,186,72,100,160,138,133,249,180,38,4,101,130,76,146,66,208,10,201,236,129,163,80,119,49,5,210,105,188,43,77,225,1,187,68,0);
	
	{PutSubImage(x,y,SubWidth,SubHeight,X index,Y index,Scale,Bitmap Pointer^,Bit operation);}
	{PutSubImage Usage}
	{X,Y Position on window of the Image placing}
	{Width of the target Sub image}
	{Height of the target sub image}
	{xoff,yoff Offsets for the sub image}
	{Scale of the image to be put to screen}
	{Pointer to the Source Bitmap}
	{Bit function to be used as described in the wingraph documentation}
	

type
	TBitSprite = record
		Bitmap,Mask:pointer;
		MaxTX,MaxTY:longint;
	end;
	
	TTileSprite = record
		Bitmap:pointer;
		MaxTX,MaxTY:longint;
	end;
	
	TMapTile = record
		Walkable:boolean;
		TileID,FloorID:byte;
	end;
	
	TPoint = record
		x,y:longint;
	end;
	
	TMap = object
		MapLoaded :boolean;
		Name : String;
		MapData  : array of TMapTile;
		procedure Draw(CameraX,CameraY:longint; TileMap:TTileSprite);
		procedure LoadMap(MapFlpth:string);
	end;
	
	Obj_Dynamic = object
		SvS,DvD,DvS:boolean;
		x,y:longint;
		vx,vy:real;
		Name:string;
		procedure DrawSelf(); virtual;
		procedure Update(fElapsed:real); virtual;
		constructor Init(ox,oy:longint; _Name:string);
	end;
	
	
	Obj_Dynamic_Creature = object(Obj_Dynamic)
		Health,MaxHealth:Word;
		Friendly,Dead:boolean;
		procedure DrawSelf(); virtual;
		procedure Update(fElapsed:real); virtual;
		constructor Init(ox,oy,_H,_MH:longint; _Name:string);
	end;
	
	{
	TList = object
		Items: array of pointer;
		function GetLength():longint;
		procedure AddObj(ObjToAdd:pointer);
		procedure DeleteObj(ObjToDelete:pointer);
		procedure DeleteIndex(Index:longint);
		destructor Clean;
	end;
	}
	
	
var TileMap:TTileSprite;	
	SpriteMap:TBitSprite;
	Map        : TMap;
	LF,CF      : Comp;
	FrameTime  : real;
	Maxx,Maxy,cx,cy,Seed,rp  : longint;
	RL : boolean;
	
	
{Good Enough Noise: GEN}	
function GetNoise(x,y:longint):byte;
var ix,iy:byte;	
	begin
	ix := abs(x) mod 256;
	iy := abs(y) mod 256;
	
	GetNoise := Noise[((ix + (Seed*ix)) + Noise[(iy*Seed) mod 256]) mod 256];	
	end;
	
function LoadSpriteMap(Width,Height:integer;BitmapFilePath,MaskFilePath:string):TBitSprite;
var f:file;
	Output:TBitSprite;
	size:longint;
begin
	with Output do
		begin
			size:=ImageSize(1,1,width,height);
			{$I-} Assign(f,BitmapFilePath); Reset(f,1); {$I+}
			if (IOResult <> 0) or (FileSize(f) <> size) then
				begin
				  writeln('Error: unable to load image file. ('+BitmapFilePath+')'+inttostr(IOResult));
				  halt(0);
				end
			else
				begin
					GetMem(Bitmap,size);
					BlockRead(f,Bitmap^,size);
				end;
			Close(f);
			
			{$I-} Assign(f,MaskFilePath); Reset(f,1); {$I+}
			if (IOResult <> 0) or (FileSize(f) <> size) then
				begin
				  writeln('Error: unable to load image file. ('+MaskFilePath+')'+inttostr(IOResult));
				  halt(0);
				end
			else
				begin
					GetMem(Mask,size);
					BlockRead(f,Mask^,size);
				end;
			Close(f);
			MaxTX := Trunc(Width/BlockWidth);
			MaxTY := Trunc(Height/BlockHeight);
		end;
	LoadSpriteMap := Output;
end;
	
function LoadTileMap(Width,Height:integer;BitmapFilePath:string):TTileSprite;
var f:file;
	Output:TTileSprite;
	size:longint;
begin
	with Output do
		begin
			size:=ImageSize(1,1,width,height);
			{$I-} Assign(f,BitmapFilePath); Reset(f,1); {$I+}
			if (IOResult <> 0) or (FileSize(f) <> size) then
				begin
				  writeln('Error: unable to load image file. ('+BitmapFilePath+')'+inttostr(IOResult));
				  halt(0);
				end
			else
				begin
					GetMem(Bitmap,size);
					BlockRead(f,Bitmap^,size);
				end;
			Close(f);
			MaxTX := Trunc(Width/BlockWidth);
			MaxTY := Trunc(Height/BlockHeight);
		end;

	LoadTileMap := Output;
end;
		
procedure PutSprite(x,y,xin,yin:smallint;Sprite:TBitSprite;UseMask:boolean);
begin
	if (xin < 0) or (yin < 0) or (yin > Sprite.MaxTY) or (xin > Sprite.MaxTX) then
		OutTextXY(0,0,'SubImageIndexError!');
	with Sprite do
		begin
			if UseMask then
				begin
					PutSubImage(x,y,BlockWidth,BlockHeight,xin,yin,ScrZoom,Mask^,AndPut);
					PutSubImage(x,y,BlockWidth,BlockHeight,xin,yin,ScrZoom,Bitmap^,OrPut);
				end
			else
				begin
					PutSubImage(x,y,BlockWidth,BlockHeight,xin,yin,ScrZoom,Bitmap^,CopyPut);
				end;
		end;
end;

function ConvToImageDatX(Index,MIX:longint):longint;	
	begin
	ConvToImageDatX := Index mod MIX;
	end;
	
function ConvToImageDatY(Index,MIX:longint):longint;	
	begin
	ConvToImageDatY := Trunc(Index/MIX);
	end;

procedure PutTile(x,y,xin,yin:smallint;Sprite:TTileSprite);
begin
	if (xin < 0) or (yin < 0) or (yin > Sprite.MaxTY) or (xin > Sprite.MaxTX) then
		OutTextXY(0,0,'SubImageIndexError!');
	with Sprite do
		begin
			PutSubImage(x,y,BlockWidth,BlockHeight,xin,yin,ScrZoom,Bitmap^,CopyPut);
		end;
end;
	
procedure Obj_Dynamic.DrawSelf();
	begin
	end;
	
procedure Obj_Dynamic.Update(fElapsed:real);
	begin
	
	end;
	
constructor Obj_Dynamic.Init(ox,oy:longint; _Name:string);
	begin
		x := ox;
		y := oy;
		Name := _Name;
	end;

constructor Obj_Dynamic_Creature.Init(ox,oy,_H,_MH:longint; _Name:string);
	begin
		x := ox;
		y := oy;
		MaxHealth := _MH;
		Health := _H;
		Name := _Name;
	end;
	
procedure Obj_Dynamic_Creature.DrawSelf();
	begin
	end;
	
procedure Obj_Dynamic_Creature.Update(fElapsed:real);
	begin
	end;
	
procedure TMap.Draw(CameraX,CameraY:longint; TileMap:TTileSprite);
var i,j,xofs,yofs,relx,rely,sx,sy,index:longint;
	MapTile:TMapTile;
	begin
		xofs := Trunc(((CameraX mod StepX)/StepX)*ScrDefX);
		yofs := Trunc(((CameraY mod StepY)/StepY)*ScrDefY);
		
		relx := Trunc((CameraX/StepX));
		rely := Trunc((CameraY/StepY));
		for i:=-CenterX to CenterX do
			begin
			for j:=-CenterY to CenterY do
				begin
				index := ((i+relx)+(Maxx*(j+rely)));
				if (i+relx < Maxx) and (j+rely < Maxy) and (i+relx >= 0) and (j+rely >= 0) then
					begin
						
						MapTile := MapData[index];
						sx := (((i*ScrDefX))-xofs)+WindowCenterX;
						sy := (((j*ScrDefY))-yofs)+WindowCenterY;
						PutTile(sx,sy,ConvToImageDatX(MapTile.TileID,TileMap.MaxTX),ConvToImageDatY(MapTile.TileID,TileMap.MaxTX),TileMap);
					end
				else
					begin
						sx := (((i*ScrDefX))-xofs)+WindowCenterX;
						sy := (((j*ScrDefY))-yofs)+WindowCenterY;
						if(GetNoise(i+relx,j+rely) > 127)then
							PutTile(sx,sy,ConvToImageDatX(DefaultID,TileMap.MaxTX),ConvToImageDatY(DefaultID,TileMap.MaxTX),TileMap)
						else
							PutTile(sx,sy,ConvToImageDatX(DefaultID+1,TileMap.MaxTX),ConvToImageDatY(DefaultID+1,TileMap.MaxTX),TileMap);
					end;
					
				end;
				
			end;
	end;
	
procedure TMap.LoadMap(MapFlpth:string);
var f:file;
	i,Offset:longint;
	Buf:array of byte;
	Temp:TMapTile;
	begin
		{$I-} Assign(f,MapFlpth+'.mmp'); Reset(f,1); {$I+}
			if (IOResult <> 0) then
				begin
				  writeln('Error: unable to load Map file. ('+MapFlpth+'.mmp)'+inttostr(IOResult));
				  halt(0);
				end
			else
				begin
					if(FileSize(f) <> 0)then
						begin
							setLength(Buf,FileSize(f));	
							BlockRead(f,Buf[0],FileSize(f));
							Close(f);
						end;
				end;
		{
		setLength(Buf,2+(3*(50*50)));
		setLength(MapData,2+(3*(50*50)));
		Buf[0] := 50;
		Buf[1] := 50;
		Offset := 0;
		i := 2;
		repeat
			Buf[i] := random(2)+9;
			inc(i);
			Buf[i] := random(2);
			inc(i);
			Buf[i] := 0;
			inc(i);
			inc(Offset);
		until (Offset = (Buf[0]*Buf[1]));	
			
		writeln(#13#10'FileLoaded');
		}
		
		
		//{$I-} Assign(f,MapFlpth+'.mmp'); Rewrite(f,1); {$I+}
		{
		BlockWrite(f,Buf[0],length(Buf));
		Close(f);
		}
		
		
		if(length(Buf) < 5)then
			begin
				  writeln('Error: unable to Parse Map file. ('+MapFlpth+'.mmp)'+inttostr(IOResult));
				  halt(0);
			end;
			
		Maxx := Buf[0];
		Maxy := Buf[1];
		setLength(MapData,(Maxx*Maxy));			
		i := 2;
		Offset := 0;
		repeat
			MapData[Offset].TileID := Buf[i];
			inc(i);
			MapData[Offset].FloorID := Buf[i];
			inc(i);
			if (Buf[i] <> 0) then
				MapData[Offset].Walkable := true
			else
				MapData[Offset].Walkable := false;
			inc(i);
			inc(Offset);
			
		until (Offset = (Maxx*Maxy));	
	end;
	
	
procedure Init();
var gd,gm:smallint;
begin
  gd:=NoPalette; gm:=mCustom;
  SetWindowSize(WindowW,WindowH);
  InitGraph(gd,gm,'RPGEngine');
  UpdateGraph(UpdateOff);
  randomize();
  Seed := random(256);
end;

begin
Init();
TileMap := LoadTileMap(144,32,'Assets\town_tiles.bmp');
SpriteMap := LoadSpriteMap(96,32,'Assets\town_tiles_Sprites.bmp','Assets\town_tiles_Sprites_Mask.bmp');
Map.LoadMap('Assets\Map0');
cx := 0;
cy := 0;
SetFillStyle(SolidFill,0);
repeat
	
	CF := TimeStampToMSecs(DateTimeToTimeStamp(Now));
	FrameTime := (CF - LF);
	LF := CF;
	if(RL)then
		inc(cx,2)
	else
		dec(cx,2);
	
	if(cx > Maxx*ScrDefX)then
		RL := false;
	
	if(cx < 1)then
		RL := true;
	cy := cx;
	
	
	Map.Draw(cx,cy,TileMap);
	PutSprite(WindowCenterX+Trunc(cos(cx/Maxx)*BlockWidth*5)-4,WindowCenterY+Trunc(sin(cx/Maxx)*BlockHeight*5)-4,0,0,SpriteMap,true);
	Bar(0,0,120,32);
	OutTextXY(0,0,'MS/Frame:'+FloatToStr(FrameTime));
	OutTextXY(0,16,'X:'+FloatToStr(round(cx/16))+',Y:'+FloatToStr(round(cy/16)));
	UpdateGraph(UpdateNow);
	delay(30);
	

	
	
until KeyPressed;
CloseGraph;
end.
