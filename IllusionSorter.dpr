{
  Illusion Sorter Console Program Unit

  License: Public Domain
}
program IllusionSorter;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  IllusionSorterLogics;

begin
  try
   InitLookupTable;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
