{
  Illusion Sorter Logics Unit

  License: Public Domain
}
unit IllusionSorterLogics;

interface

uses SysUtils, Windows, Classes;

{ PNG uses Big Endian numbers, hence why we need this function to properly read its size fields. }
function EndianSwap(i: longword) : longword;

procedure LookupAdd(MFFlags : byte; IDs, Paths, Magics : string);
procedure InitLookupTable;

function IsValidPNGImage(CardStream : TStream) : boolean;
function IsValidCard(CardStream : TStream) : boolean;

{ 
  Older Illusion cards (AA2) are done in a fun way. The header location is actually stored in the last
  4 bytes after the second PNG's IEND chunk in a form of reverse offset. Which means you have to go
  the amount of bytes BACKWARDS to read the header, thus skipping the PNG part completely.
  
  But alas, the Unity-based game cards no longer follow that scheme, so we'll have to parse the entire
  PNG structure anyway.
  
  Although, we don't read the actual image's data nor validate the values (for the most part). This
  merely helps us skip to proper offset and read the correct Illusion's card header without any
  false-positives.
}

type TPNGHdr = packed record
  Magic : array[1..8] of char; // #$89+'PNG'+#$D+#$A+#$1A+#$A
end;

{ All PNG chunks have the exact same structure. }
type TPNGChunkHdr = packed record
  Size : longword; // Big endian. To get full chunk size with header itself, add 8 after reading the Size to include and skip the whole chunk with headers
  Magic : array[1..4] of char; // As soon as we hit the "IEND" chunk, the cycle of chunk reading should stop
end;
{ Here goes the data that's pointed in the Size variable }
type TPNGChunkEnd = packed record
  CRC32 : longword; // Hash at the end of chunk
end;

{ The Unity-based game cards have this header structure. Previous games like AA2 do not. }
type TIlluCard = packed record
  Magic : longword; // $64
  LengthID : byte;  // length of identification string
//Field : string;
  LengthVer : byte; // length of version string
//Version : string;
  NextData : longword; // how many bytes to skip for the next chunk of game data. The size of second PNG image (usually a mini-thumbnail)
end;

{ For storing the ID - target directory pairs }
type IllusionID = packed record
  MFFlag : byte;   // Has male / female cards (and needs extra steps)
  ID     : string; // Format description
  Path   : string; // Basic path for saving (will get appended "male" or "female" if MFDiff is > 0)
                    // The male card has "sex" field set to 0x00, female is 0x01.
                    // In hex, it looks like "sex"+#$00 or "sex"+#$01.
  Magic  : string; // Header string in UTF-8
end;

var LookupTable : array of IllusionID;

implementation

function EndianSwap(i: longword) : longword;
asm
  bswap eax
end;

procedure LookupAdd(MFFlags : byte; IDs, Paths, Magics : string);
begin
  SetLength(LookupTable,Length(LookupTable)+1);
  with LookupTable[Length(LookupTable)-1] do begin
    MFFlag := MFFlags;
    ID     := IDs;
    Path   := Paths;
    Magic  := Magics;
  end;
end;

procedure InitLookupTable;
const
    { UTF-8 Japanese brackets }
      JOp = #$e3#$80#$90; // open
      JCl = #$e3#$80#$91; // closed
begin
  SetLength(LookupTable,0); // Init array

  // Application will default to 'trash' directory for invalid files
  LookupAdd(0, 'Not a valid card',           'trash',         '');

  LookupAdd(1, 'Koikatsu Character',         'kk_chara',      JOp+'KoiKatuChara'+JCl);
  LookupAdd(0, 'Koikatsu Coordinate',        'kk_coordinate', JOp+'KoiKatuClothes'+JCl);
  LookupAdd(0, 'Koikatsu Studio Scene',      'kk_scene',      JOp+'KStudio'+JCl);

  LookupAdd(1, 'Emotion Creators Character', 'ec_chara',      JOp+'EroMakeChara'+JCl);
  LookupAdd(0, 'Emotion Creators Map',       'ec_map',        JOp+'EroMakeMap'+JCl);

  LookupAdd(0, 'AI Girl Character',          'ai_chara',      JOp+'AIS_Chara'+JCl);

  LookupAdd(1, 'Artificial Academy 2',       'aa2_chara',     #$81#$79#$83#$47#$83#$66#$83#$42#$83#$62#$83#$67#$81#$7A); // 【エディット】 in Shift-JIS

end;

function IsValidPNGImage(CardStream : TStream) : boolean;
var PNGHdr      : TPNGHdr;
    PNGChunk    : TPNGChunkHdr;
    PNGChunkEnd : TPNGChunkEnd;
    ChunkSize   : longword;
begin
 Result := False;

 with CardStream do begin

  // Sanity check: make sure we have at least one full IEND chunk to read
  if Size >= (SizeOf(PNGHdr)+SizeOf(PNGChunk)+SizeOf(PNGChunkEnd)) then begin
   
   Read(PNGHdr,SizeOf(PNGHdr));

   // If header is damaged / not a valid PNG image file
   if PNGHdr.Magic <> #$89'PNG'#$D#$A#$1A#$A then Exit;

   // Reading PNG chunks one by one
   while PNGChunk.Magic <> 'IEND' do begin
    
    Read(PNGChunk,SizeOf(PNGChunk));

    ChunkSize := EndianSwap(PNGChunk.Size);
    
    // Sanity check: what if we suddenly ran out of file?
    if (Size - Position) < ChunkSize then Exit;

    // Skipping data inside of chunk. Do NOT seek if the size is 0
    if ChunkSize > 0 then Seek(ChunkSize,soCurrent);
    
    // Reading CRC32
    Read(PNGChunkEnd,SizeOf(PNGChunkEnd));

   end;
   
   Result := True;

  end;
   
 end;
 
end;

function DetectCard(CardStream : TStream; FileName : widestring) : string;
var i,j : longword;
begin

  // to-do: give card the appropriate place to live

end;

end.
