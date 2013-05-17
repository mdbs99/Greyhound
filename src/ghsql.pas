{
    Greyhound
    Copyright (C) 2012-2013  -  Marcos Douglas B. dos Santos

    See the files COPYING.GH, included in this
    distribution, for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
}

unit ghSQL;

{$i ghdef.inc}

interface

uses
  // fpc
  Classes, SysUtils, DB, contnrs, fgl, BufDataset, sqldb,
  // gh
  ghData;

type
  EghSQLError = class(EghDataError);
  TghSQLObject = class(TghDataObject);

{ Forward declarations }

  TghSQLStatement = class;
  TghSQLConnector = class;
  TghSQLTable = class;
  TghSQLTableList = class;
  TghSQLConstraintList = class;

{ Interfaces }

  IghSQLDataSetResolver = interface(IghDataSet)
    procedure SetTableName(const ATableName: string);
    function GetServerIndexDefs: TIndexDefs;
    procedure ApplyUpdates;
    procedure CancelUpdates;
  end;

{ Classes }

  { TghSQLStatement }

  TghSQLStatement = class(TghSQLObject)
  protected
    FParamsCheck: Boolean;
    FParams: TghDataParams;
    FScript: TStringList;
    procedure DoChangeScript(Sender: TObject);
  public
    constructor Create; override;
    destructor Destroy; override;
    procedure Assign(ASource: TghSQLStatement); virtual;
    procedure Clear; virtual;
    property ParamsCheck: Boolean read FParamsCheck write FParamsCheck;
    property Params: TghDataParams read FParams;
    property Script: TStringList read FScript;
  end;

  EghSQLHandlerError = class(EghSQLError);
  TghSQLHandler = class(TghSQLStatement)
  protected
    FIsBatch: Boolean;
    FPacketRecords: Integer;
    FPrepared: Boolean;
    procedure SetPacketRecords(AValue: Integer); virtual;
  public
    constructor Create; override;
    procedure Assign(ASource: TghSQLStatement); override;
    procedure Clear; override;
    property IsBatch: Boolean read FIsBatch write FIsBatch;
    property PacketRecords: Integer read FPacketRecords write SetPacketRecords;
    property Prepared: Boolean read FPrepared write FPrepared;
  end;

  TghSQLEventHandler = class(TghSQLHandler)
  protected
    FBeforeOpen: TNotifyEvent;
    FAfterOpen: TDataSetNotifyEvent;
    FBeforeExecute: TNotifyEvent;
    FAfterExecute: TNotifyEvent;
    procedure DoBeforeOpen;
    procedure DoAfterOpen(ADataSet: TDataSet);
    procedure DoBeforeExecute;
    procedure DoAfterExecute;
    procedure InternalOpen(Sender: TObject; out ADataSet: TDataSet; AOwner: TComponent = nil); virtual; abstract;
    function InternalExecute(Sender: TObject): NativeInt; virtual; abstract;
  public
    procedure Open(out ADataSet: TDataSet; AOwner: TComponent = nil); virtual;
    function Execute: NativeInt; virtual;
    property BeforeOpen: TNotifyEvent read FBeforeOpen write FBeforeOpen;
    property AfterOpen: TDataSetNotifyEvent read FAfterOpen write FAfterOpen;
    property BeforeExecute: TNotifyEvent read FBeforeExecute write FBeforeExecute;
    property AfterExecute: TNotifyEvent read FAfterExecute write FAfterExecute;
  end;

  TghSQLClient = class(TghSQLEventHandler)
  protected
    FConnector: TghSQLConnector;
    procedure InternalOpen(Sender: TObject; out ADataSet: TDataSet; AOwner: TComponent = nil); override;
    function InternalExecute(Sender: TObject): NativeInt; override;
  public
    constructor Create(AConn: TghSQLConnector); virtual; reintroduce;
  end;

  TghSQLConstraint = class(TghSQLObject)
  protected
    FParams: TghDataParams;
    FTable: TghSQLTable;
    procedure SetTable(AValue: TghSQLTable);
    function NamesToBeautifulStr: string;
    function ValuesToBeautifulStr: string;
  public
    constructor Create; override;
    destructor Destroy; override;
    procedure Execute; virtual; abstract;
    property Table: TghSQLTable read FTable write SetTable;
  end;

  TghSQLDefaultConstraint = class(TghSQLConstraint)
  public
    constructor Create(const AColumName: string; AValue: Variant); reintroduce;
    procedure Execute; override;
  end;

  TghSQLValidationConstraint = class(TghSQLConstraint)
  protected
    FError: string;
  public
    function GetError: string; virtual;
  end;

  TghSQLUniqueConstraint = class(TghSQLValidationConstraint)
  public
    constructor Create(const AColumNames: array of string; const AError: string = ''); reintroduce;
    procedure Execute; override;
  end;

  TghSQLCheckConstraint = class(TghSQLValidationConstraint)
  public
    constructor Create(const AColumName: string; AValues: array of Variant; const AError: string = ''); reintroduce;
    procedure Execute; override;
  end;

  TghSQLConstraintList = class(specialize TFPGObjectList<TghSQLConstraint>)
  private
    FOwnerTable: TghSQLTable;
    procedure SetOwnerTable(AValue: TghSQLTable);
  public
    // Add a Default constraint
    function AddDefault(const AColumName: string; AValue: Variant): Integer; overload;
    // Add a Unique constraint
    function AddUnique(const AColumNames: array of string; const AError: string = ''): Integer;
    // Add a Check constraint
    function AddCheck(const AColumName: string; AValues: array of Variant; const AError: string = ''): Integer;
    property OwnerTable: TghSQLTable read FOwnerTable write SetOwnerTable;
  end;

  TghSQLTable = class(TghSQLHandler)
  private
    FConnector: TghSQLConnector;
    FTableName: string;
    FConditions: string;
    FErrors: TStrings;
    FLinks: TghSQLTableList;
    FOrderBy: string;
    FOwnerTable: TghSQLTable;
    FReuse: Boolean;
    FSelectColumns: string;
    FEnforceConstraints: Boolean;
    FUseRetaining: Boolean;
    FBeforeOpen: TNotifyEvent;
    FAfterOpen: TNotifyEvent;
    FBeforePost: TNotifyEvent;
    FAfterPost: TNotifyEvent;
    FBeforeCommit: TNotifyEvent;
    FAfterCommit: TNotifyEvent;
    class var FRelations: TFPHashObjectList;
    class var FConstraints: TFPHashObjectList;
    function GetActive: Boolean;
    function GetColumn(const AName: string): TghDataColumn;
    function GetEOF: Boolean;
    function GetConnector: TghSQLConnector;
    procedure SetConnector(AValue: TghSQLConnector);
    function GetConstraints: TghSQLConstraintList;
    function GetRelations: TghSQLTableList;
    procedure SetTableName(const AValue: string);
    function GetState: TDataSetState;
    function GetIsEmpty: Boolean;
    function GetRecordCount: Longint;
    procedure FillAutoParams(ASource: TghSQLTable);
    function GetDataset: TDataSet;
  protected
    FData: TDataSet;
    class procedure ClassInitialization;
    class procedure ClassFinalization;
    procedure SetPacketRecords(AValue: Integer); override;
    procedure CheckData;
    procedure InternalCommit(ARetaining: Boolean); virtual;
    procedure InternalRollback(ARetaining: Boolean); virtual;
    function CheckValues: Boolean; virtual;
    procedure SetDefaultValues; virtual;
    // events
    procedure DoBeforeOpen; virtual;
    procedure DoAfterOpen; virtual;
    procedure DoBeforePost; virtual;
    procedure DoAfterPost; virtual;
    procedure DoBeforeCommit; virtual;
    procedure DoAfterCommit; virtual;
    // callback
    procedure CallFoundTable(Sender: TObject; ATable: TghSQLTable); virtual;
  public
    constructor Create(AConn: TghSQLConnector); virtual; overload;
    constructor Create(AConn: TghSQLConnector; const ATableName: string); virtual; overload;
    constructor Create(AConn: TghSQLConnector; const ATableName: string; AOwnerTable: TghSQLTable); virtual; overload;
    destructor Destroy; override;
    procedure Assign(ASource: TghSQLStatement); override;
    procedure Clear; override;
    function Close: TghSQLTable;
    function Open: TghSQLTable;
    function Insert: TghSQLTable;
    function Append: TghSQLTable;
    function Edit: TghSQLTable;
    function Post: TghSQLTable;
    function Cancel: TghSQLTable;
    function Delete: TghSQLTable;
    function DeleteAll: TghSQLTable;
    function Commit: TghSQLTable;
    function CommitRetaining: TghSQLTable;
    function Rollback: TghSQLTable;
    function RollbackRetaining: TghSQLTable;
    function Refresh: TghSQLTable;
    function First: TghSQLTable;
    function Prior: TghSQLTable;
    function Next: TghSQLTable;
    function Last: TghSQLTable;
    function Select(const AColumnNames: string): TghSQLTable;
    function Where(const AConditions: string): TghSQLTable; overload;
    function Where(const AConditionsFmt: string; AArgs: array of const): TghSQLTable; overload;
    function OrderBy(const AColumnNames: string): TghSQLTable;
    function GetColumns: TghDataColumns;
    function HasErrors: Boolean;
    function GetErrors: TStrings;
    procedure SetDataRow(ADataRow: TghDataRow);
    property Active: Boolean read GetActive;
    property Columns[const AName: string]: TghDataColumn read GetColumn; default;
    property Connector: TghSQLConnector read GetConnector write SetConnector;
    property State: TDataSetState read GetState;
    property EOF: Boolean read GetEOF;
    property IsEmpty: Boolean read GetIsEmpty;
    property Links: TghSQLTableList read FLinks;
    property OwnerTable: TghSQLTable read FOwnerTable write FOwnerTable;
    property Reuse: Boolean read FReuse write FReuse;
    property RecordCount: Longint read GetRecordCount;
    property TableName: string read FTableName write SetTableName;
    property Relations: TghSQLTableList read GetRelations;
    property Constraints: TghSQLConstraintList read GetConstraints;
    property EnforceConstraints: Boolean read FEnforceConstraints;
    property UseRetaining: Boolean read FUseRetaining write FUseRetaining;
    property BeforeOpen: TNotifyEvent read FBeforeOpen write FBeforeOpen;
    property AfterOpen: TNotifyEvent read FAfterOpen write FAfterOpen;
    property BeforePost: TNotifyEvent read FBeforePost write FBeforePost;
    property AfterPost: TNotifyEvent read FAfterPost write FAfterPost;
    property BeforeCommit: TNotifyEvent read FBeforeCommit write FBeforeCommit;
    property AfterCommit: TNotifyEvent read FAfterCommit write FAfterCommit;
    property DataSet: TDataSet read GetDataset;
  end;

  TghSQLTableNotifyEvent = procedure (Sender: TObject; ATable: TghSQLTable) of object;
  TghSQLTableList = class(specialize TFPGObjectList<TghSQLTable>)
  private
    FLocked: Boolean;
    FOwnerTable: TghSQLTable;
    FOnNewTable: TghSQLTableNotifyEvent;
    FOnFoundTable: TghSQLTableNotifyEvent;
    function GetTables(const ATableName: string): TghSQLTable;
    // events
    procedure DoNewTable(ATable: TghSQLTable);
    procedure DoFoundTable(ATable: TghSQLTable);
  public
    constructor Create(AOwnerTable: TghSQLTable; AFreeObjects: Boolean = True); virtual; reintroduce;
    destructor Destroy; override;
    function FindByName(const AName: string): TghSQLTable;
    procedure Lock;
    procedure UnLock;
    property Tables[const ATableName: string]: TghSQLTable read GetTables; default;
    property OnNewTable: TghSQLTableNotifyEvent read FOnNewTable write FOnNewTable;
    property OnFoundTable: TghSQLTableNotifyEvent read FOnFoundTable write FOnFoundTable;
  end;

  EghSQLLibError = class(EghSQLError);
  TghSQLLibClass = class of TghSQLLib;
  TghSQLLib = class abstract(TghSQLEventHandler)
  protected
    FConnector: TghSQLConnector;
  public
    constructor Create(var AConnector: TghSQLConnector); virtual; reintroduce;
    procedure Connect; virtual; abstract;
    function Connected: Boolean; virtual; abstract;
    procedure Disconnect; virtual; abstract;
    procedure StartTransaction; virtual; abstract;
    function InTransaction: Boolean; virtual; abstract;
    procedure Commit; virtual; abstract;
    procedure CommitRetaining; virtual; abstract;
    procedure Rollback; virtual; abstract;
    procedure RollbackRetaining; virtual; abstract;
    function GetLastAutoIncValue: NativeInt; virtual;
    function GetSequenceValue(const ASequenceName: string): NativeInt; virtual; abstract;
  end;

  TghSQLConnector = class(TghSQLObject)
  strict private
    FTransCount: SmallInt;
    FHost: string;
    FDatabase: string;
    FUser: string;
    FPassword: string;
    FTables: TghSQLTableList;
  protected
    FLib: TghSQLLib;
    function GetConnected: Boolean;
    // callback
    procedure CallNewTable(Sender: TObject; ATable: TghSQLTable); virtual;
  public
    constructor Create(ALib: TghSQLLibClass); virtual; reintroduce;
    destructor Destroy; override;
    procedure SetLibClass(ALib: TghSQLLibClass);
    procedure Connect; virtual;
    procedure Disconnect; virtual;
    procedure StartTransaction;
    function InTransaction: Boolean;
    procedure Commit;
    procedure CommitRetaining;
    procedure Rollback;
    procedure RollbackRetaining;
    procedure Notify(ATable: TghSQLTable; AOperation: TOperation); virtual;
    property Lib: TghSQLLib read FLib;
    property Connected: Boolean read GetConnected;
    property Host: string read FHost write FHost;
    property Database: string read FDatabase write FDatabase;
    property User: string read FUser write FUser;
    property Password: string read FPassword write FPassword;
    property Tables: TghSQLTableList read FTables;
  end;

implementation

{ TghSQLStatement }

procedure TghSQLStatement.DoChangeScript(Sender: TObject);
var
  NewParams: TghDataParams;
begin
  if not FParamsCheck then
    Exit;

  // Preserve existing param values
  NewParams := TghDataParams.Create(nil);
  try
    NewParams.ParseSQL(FScript.Text, True, True, True, psInterbase);
    NewParams.AssignValues(FParams);
    FParams.Assign(NewParams);
  finally
    NewParams.Free;
  end;
end;

constructor TghSQLStatement.Create;
begin
  inherited;
  FParams := TghDataParams.Create;
  FScript := TStringList.Create;
  FScript.OnChange := @DoChangeScript;
end;

destructor TghSQLStatement.Destroy;
begin
  FParams.Free;
  FScript.Free;
  inherited Destroy;
end;

procedure TghSQLStatement.Assign(ASource: TghSQLStatement);
begin
  FScript.Assign(ASource.Script);
  FParams.Assign(ASource.Params);
end;

procedure TghSQLStatement.Clear;
begin
  FScript.Clear;
  FParams.Clear;
end;

{ TghSQLHandler }

procedure TghSQLHandler.SetPacketRecords(AValue: Integer);
begin
  if FPacketRecords = AValue then
    Exit;
  FPacketRecords := AValue;
end;

constructor TghSQLHandler.Create;
begin
  inherited Create;
  FPacketRecords := -1;
end;

procedure TghSQLHandler.Assign(ASource: TghSQLStatement);
var
  Handler: TghSQLHandler;
begin
  inherited;
  if ASource is TghSQLHandler then
  begin
    Handler := TghSQLHandler(ASource);
    Self.IsBatch := Handler.IsBatch;
    Self.Prepared := Handler.Prepared;
    Self.PacketRecords := Handler.PacketRecords;
  end;
end;

procedure TghSQLHandler.Clear;
begin
  inherited Clear;
  FIsBatch := False;
  FPacketRecords := -1;
  FPrepared := False;
end;

{ TghSQLEventHandler }

procedure TghSQLEventHandler.DoBeforeOpen;
begin
  if Assigned(FBeforeOpen) then
    FBeforeOpen(Self);
end;

procedure TghSQLEventHandler.DoAfterOpen(ADataSet: TDataSet);
begin
  if Assigned(FAfterOpen) then
    FAfterOpen(ADataSet);
end;

procedure TghSQLEventHandler.DoBeforeExecute;
begin
  if Assigned(FBeforeExecute) then
    FBeforeExecute(Self);
end;

procedure TghSQLEventHandler.DoAfterExecute;
begin
  if Assigned(FAfterExecute) then
    FAfterExecute(Self);
end;

procedure TghSQLEventHandler.Open(out ADataSet: TDataSet; AOwner: TComponent);
begin
  DoBeforeOpen;
  InternalOpen(Self, ADataSet, AOwner);
  DoAfterOpen(ADataSet);
end;

function TghSQLEventHandler.Execute: NativeInt;
begin
  DoBeforeExecute;
  Result := InternalExecute(Self);
  DoAfterExecute;
end;

{ TghSQLClient }

procedure TghSQLClient.InternalOpen(Sender: TObject; out ADataSet: TDataSet;
  AOwner: TComponent);
var
  OldHandler: TghSQLHandler;
begin
  OldHandler := TghSQLHandler.Create;
  try
    OldHandler.Assign(FConnector.Lib);
    ADataSet := nil;
    try
      if not FConnector.Connected then
        FConnector.Connect;
      FConnector.StartTransaction;
      FConnector.Lib.Assign(Self);
      FConnector.Lib.Open(ADataSet, AOwner);
      FConnector.CommitRetaining;
    except
      FConnector.RollbackRetaining;
      ADataSet.Free;
      raise;
    end;
  finally
    FConnector.Lib.Assign(OldHandler);
    OldHandler.Free;
  end;
end;

function TghSQLClient.InternalExecute(Sender: TObject): NativeInt;
var
  OldHandler: TghSQLHandler;
begin
  OldHandler := TghSQLHandler.Create;
  try
    OldHandler.Assign(FConnector.Lib);
    try
      if not FConnector.Connected then
        FConnector.Connect;
      FConnector.StartTransaction;
      FConnector.Lib.Assign(Self);
      Result := FConnector.Lib.Execute;
      FConnector.CommitRetaining;
    except
      FConnector.RollbackRetaining;
      raise;
    end;
  finally
    FConnector.Lib.Assign(OldHandler);
    OldHandler.Free;
  end;
end;

constructor TghSQLClient.Create(AConn: TghSQLConnector);
begin
  inherited Create;
  FConnector := AConn;
end;

{ TghSQLConstraint }

procedure TghSQLConstraint.SetTable(AValue: TghSQLTable);
begin
  if FTable = AValue then Exit;
  FTable := AValue;
end;

function TghSQLConstraint.NamesToBeautifulStr: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to FParams.Count-1 do
  begin
    if (I > 0) and (I = FParams.Count-1) then
      Result += ' and '
    else if I > 0 then
      Result += ', ';
    Result += FParams.Items[I].Name;
  end;
end;

function TghSQLConstraint.ValuesToBeautifulStr: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to FParams.Count-1 do
  begin
    if (I > 0) and (I = FParams.Count-1) then
      Result += ' and '
    else if I > 0 then
      Result += ', ';
    Result += FParams.Items[I].AsString;
  end;
end;

constructor TghSQLConstraint.Create;
begin
  inherited Create;
  FParams := TghDataParams.Create;
end;

destructor TghSQLConstraint.Destroy;
begin
  FParams.Free;
  inherited Destroy;
end;

{ TghSQLDefaultConstraint }

constructor TghSQLDefaultConstraint.Create(const AColumName: string;
  AValue: Variant);
begin
  inherited Create;
  FParams[AColumName].Value := AValue;
end;

procedure TghSQLDefaultConstraint.Execute;
var
  I: Integer;
  Col: TghDataColumn;
begin
  for I := 0 to FParams.Count -1 do
  begin
    Col := FTable.GetColumns.FindField(FParams.Items[I].Name);
    if Assigned(Col) then
      Col.Value := FParams.Items[I].Value;
  end;
end;

{ TghSQLValidationConstraint }

function TghSQLValidationConstraint.GetError: string;
begin
  Result := FError;
end;

{ TghSQLUniqueConstraint }

constructor TghSQLUniqueConstraint.Create(const AColumNames: array of string;
  const AError: string);
var
  I: Integer;
begin
  inherited Create;

  for I := Low(AColumNames) to High(AColumNames) do
    FParams[AColumNames[I]];

  FError := AError;
  if FError = '' then
    FError := Format('Violated unique constraint for column(s) %s.', [NamesToBeautifulStr]);
end;

procedure TghSQLUniqueConstraint.Execute;
var
  SC: TghSQLClient;
  DS: TDataSet;

  procedure FilterUsingIndexDefs;
  var
    I: Integer;
    IxDef: TIndexDef;
  begin
    with FTable.FData as IghSQLDataSetResolver do
    begin
      for I := 0 to GetServerIndexDefs.Count -1 do
      begin
        IxDef := GetServerIndexDefs[I];
        if ixPrimary in IxDef.Options then
        begin
          if not FTable[IxDef.Fields].IsNull then
          begin
            SC.Script.Add('and (' + IxDef.Fields + ' <> :' + IxDef.Fields + ')');
            SC.Params[IxDef.Fields].Value := FTable[IxDef.Fields].Value;
          end;
        end;
      end;
    end;
  end;

  procedure FilterUsingParams;
  var
    I: Integer;
    Par: TParam;
    Col: TghDataColumn;
  begin
    for I := 0 to FParams.Count -1 do
    begin
      Par := FParams.Items[I];
      Col := FTable.GetColumns.FindField(Par.Name);
      if Col = nil then
        raise EghSQLError.CreateFmt(Self, 'Column "%s" not found.', [Par.Name]);
      SC.Script.Add('and (' + Par.Name + ' = :' + Par.Name + ')');
      SC.Params[Par.Name].Value := Col.Value;
    end;
  end;

begin
  SC := TghSQLClient.Create(FTable.Connector);
  try
    SC.Script.Add('select 1 from ' + FTable.TableName);
    SC.Script.Add('where 1=1');
    FilterUsingIndexDefs;
    FilterUsingParams;
    SC.Open(DS);
    if not DS.IsEmpty then
      FTable.GetErrors.Add(GetError);
  finally
    DS.Free;
    SC.Free;
  end;
end;

{ TghSQLCheckConstraint }

constructor TghSQLCheckConstraint.Create(const AColumName: string;
  AValues: array of Variant; const AError: string);
var
  I: Integer;
begin
  inherited Create;
  for I := Low(AValues) to High(AValues) do
  begin
    with TParam.Create(FParams) do
    begin
      Name := AColumName;
      Value := AValues[I];
    end;
  end;

  FError := AError;
  if FError = '' then
    FError := Format('Violated the check constraint for column %s. The permitted values are %s',
                     [FParams.Items[0].Name, ValuesToBeautifulStr]);
end;

procedure TghSQLCheckConstraint.Execute;
var
  I: Integer;
  Par: TParam;
  Col: TghDataColumn;
  Bo: Boolean;
begin
  Par := FParams.Items[0];
  Col := FTable.GetColumns.FindField(Par.Name);

  if Col = nil then
    raise EghSQLError.CreateFmt(Self, 'Column "%s" not found.', [Par.Name]);

  Bo := False;
  for I := 0 to FParams.Count -1 do
  begin
    if Col.Value = FParams.Items[I].Value then
    begin
      Bo := True;
      Break;
    end;
  end;

  if not Bo then
    FTable.GetErrors.Add(GetError);
end;

{ TghSQLConstraintList }

procedure TghSQLConstraintList.SetOwnerTable(AValue: TghSQLTable);
begin
  if FOwnerTable = AValue then Exit;
  FOwnerTable := AValue;
end;

function TghSQLConstraintList.AddDefault(const AColumName: string; AValue: Variant): Integer;
var
  C: TghSQLConstraint;
begin
  C := TghSQLDefaultConstraint.Create(AColumName, AValue);
  C.Table := FOwnerTable;
  Result := Add(C);
end;

function TghSQLConstraintList.AddUnique(const AColumNames: array of string;
  const AError: string = ''): Integer;
var
  C: TghSQLConstraint;
begin
  C := TghSQLUniqueConstraint.Create(AColumNames, AError);
  C.Table := FOwnerTable;
  Result := Add(C);
end;

function TghSQLConstraintList.AddCheck(const AColumName: string;
  AValues: array of Variant; const AError: string): Integer;
var
  C: TghSQLConstraint;
begin
  C := TghSQLCheckConstraint.Create(AColumName, AValues, AError);
  C.Table := FOwnerTable;
  Result := Add(C);
end;

{ TghSQLTable }

function TghSQLTable.GetActive: Boolean;
begin
  Result := Assigned(FData) and FData.Active;
end;

function TghSQLTable.GetColumn(const AName: string): TghDataColumn;
begin
  CheckData;
  Result := TghDataColumn(FData.FieldByName(AName));
end;

function TghSQLTable.GetEOF: Boolean;
begin
  CheckData;
  Result := FData.EOF;
end;

function TghSQLTable.GetConnector: TghSQLConnector;
begin
  Result := FConnector;
end;

procedure TghSQLTable.SetConnector(AValue: TghSQLConnector);
begin
  if Self.Active then
    raise EghSQLError.Create(Self, 'Table is active.');

  if (AValue = nil) or (FConnector = AValue) then
    Exit;

  if Assigned(FConnector) then
    FConnector.Notify(Self, opRemove);

  FConnector := AValue;
  FConnector.Notify(Self, opInsert);
end;

function TghSQLTable.GetRelations: TghSQLTableList;
begin
  Result := TghSQLTableList(FRelations.Find(FTableName));
  if Result = nil then
  begin
    Result := TghSQLTableList.Create(Self, True);
    FRelations.Add(FTableName, Result);
  end;
end;

function TghSQLTable.GetConstraints: TghSQLConstraintList;
begin
  Result := TghSQLConstraintList(FConstraints.Find(FTableName));
  if Result = nil then
  begin
    Result := TghSQLConstraintList.Create(True);
    Result.OwnerTable := Self;
    FConstraints.Add(FTableName, Result);
  end;
end;

procedure TghSQLTable.SetTableName(const AValue: string);
begin
  if FTableName = AValue then
    Exit;

  if Self.Active then
    raise EghSQLError.Create(Self, 'Table is active.');

  FTableName := AValue;
end;

function TghSQLTable.GetState: TDataSetState;
begin
  CheckData;
  Result := FData.State;
end;

function TghSQLTable.GetIsEmpty: Boolean;
begin
  CheckData;
  Result := FData.IsEmpty;
end;

function TghSQLTable.GetRecordCount: Longint;
begin
  CheckData;
  Result := FData.RecordCount;
end;

procedure TghSQLTable.FillAutoParams(ASource: TghSQLTable);
var
  I: Integer;
  Fld: TField;
  S: string;
begin
  S := LowerCase(Self.FConditions);
  if S = '' then
    Exit;
  for I := 0 to ASource.FData.Fields.Count-1 do
  begin
    Fld := ASource.FData.Fields[I];
    if Pos(':' + LowerCase(Fld.FieldName), S) > 0 then
    begin
      Self.Params[Fld.FieldName].Value := Fld.Value;
    end;
  end;
end;

function TghSQLTable.GetDataset: TDataSet;
begin
  Result := FData;
end;

class procedure TghSQLTable.ClassInitialization;
begin
  FRelations := TFPHashObjectList.Create(True);
  FConstraints := TFPHashObjectList.Create(True);
end;

class procedure TghSQLTable.ClassFinalization;
begin
  FRelations.Free;
  FConstraints.Free;
end;

procedure TghSQLTable.SetPacketRecords(AValue: Integer);
begin
  if Active then
    (FData as IghDataSet).PacketRecords := AValue;
  inherited SetPacketRecords(AValue);
end;

procedure TghSQLTable.CheckData;
begin
  if not Active then
    raise EghSQLError.Create(Self, 'Table data is not active');
end;

procedure TghSQLTable.InternalCommit(ARetaining: Boolean);
begin
  if FData.State in [dsInsert, dsEdit] then
  begin
    if Post.HasErrors then
      raise EghSQLError.Create(Self, FErrors.Text);
  end;

  FConnector.StartTransaction;
  try
    DoBeforeCommit;
    with FData as IghSQLDataSetResolver do
    begin
      SetTableName(FTableName);
      ApplyUpdates;
    end;
    if ARetaining then
      FConnector.CommitRetaining
    else
      FConnector.Commit;
    FErrors.Clear;
    DoAfterCommit;
  except
    on e: Exception do
    begin
      if ARetaining then
        FConnector.RollbackRetaining
      else
        FConnector.Rollback;
      raise EghSQLError.Create(Self, e.Message);
    end;
  end;
end;

procedure TghSQLTable.InternalRollback(ARetaining: Boolean);
begin
  if ARetaining then
    FConnector.RollbackRetaining
  else
    FConnector.Rollback;
  (FData as IghSQLDataSetResolver).CancelUpdates;
  FErrors.Clear;
end;

function TghSQLTable.CheckValues: Boolean;
var
  I: Integer;
begin
  Result := True;

  if not FEnforceConstraints then
    Exit;

  for I := 0 to GetConstraints.Count -1 do
  begin
    if GetConstraints[I] is TghSQLValidationConstraint then
      with TghSQLValidationConstraint(GetConstraints[I]) do
      begin
        Table := Self;
        Execute;
      end;
  end;
  Result := FErrors.Count = 0;
end;

procedure TghSQLTable.SetDefaultValues;
var
  I: Integer;
  C: TghSQLConstraint;

  procedure LocalFillFieldValues;
  var
    I, X: Integer;
    Fld: TField;
    Par: TParam;
    Templates: array[1..3] of string;
  begin
    Templates[1] := 'id_'+OwnerTable.TableName; // id_table
    Templates[2] := OwnerTable.TableName+'_id'; // table_id
    Templates[3] := 'id'+OwnerTable.TableName;  // idtable

    for I := 0 to Params.Count-1 do
    begin
      Par := Params.Items[I];
      // Check if table belongs_to owner
      // TODO: Test not only "id" name
      // TODO: Use OwnerTable.GetServerIndexDefs to get the right fields and
      //       to know which fields should be initialized , eg, user_id = :id
      if SameText('id', Par.Name) then
      begin
        for X := Low(Templates) to High(Templates) do
        begin
          Fld := FData.Fields.FindField(Templates[X]);
          if Assigned(Fld) then
          begin
            Fld.Value := Par.Value;
            Break;
          end;
        end;
      end;
    end;
  end;

begin
  for I := 0 to GetConstraints.Count -1 do
  begin
    C := GetConstraints[I];
    if C is TghSQLDefaultConstraint then
    begin
      C.Table := Self;
      TghSQLDefaultConstraint(C).Execute;
    end;
  end;

  // get default values in OwnerTable
  if Assigned(OwnerTable) then
  begin
    LocalFillFieldValues;
    FillAutoParams(OwnerTable);
  end;
end;

procedure TghSQLTable.DoBeforeOpen;
begin
  if Assigned(FBeforeOpen) then
    FBeforeOpen(Self);
end;

procedure TghSQLTable.DoAfterOpen;
begin
  if Assigned(FAfterOpen) then
    FAfterOpen(Self);
end;

procedure TghSQLTable.DoBeforePost;
begin
  if Assigned(FBeforePost) then
    FBeforePost(Self);
end;

procedure TghSQLTable.DoAfterPost;
begin
  if Assigned(FAfterPost) then
    FAfterPost(Self);
end;

procedure TghSQLTable.DoBeforeCommit;
begin
  if Assigned(FBeforeCommit) then
    FBeforeCommit(Self);
end;

procedure TghSQLTable.DoAfterCommit;
begin
  if Assigned(FAfterCommit) then
    FAfterCommit(Self);
end;

procedure TghSQLTable.CallFoundTable(Sender: TObject; ATable: TghSQLTable);
var
  TableModel: TghSQLTable;
begin
  CheckData;
  TableModel := GetRelations.FindByName(ATable.TableName);
  if not Assigned(TableModel) then
    raise EghSQLError.CreateFmt(Self, 'Model "%s" not found.', [ATable.TableName]);

  if not ATable.Active then
  begin
    ATable.Connector := FConnector;
    ATable.OwnerTable := Self;
    ATable.Reuse := False;  // TODO: important?
  end;

  ATable.Close;
  ATable.Assign(TableModel);
  ATable.FillAutoParams(Self);

  if Assigned(TableModel.Params) then
    ATable.Params.AssignValues(TableModel.Params);

  ATable.Open;
end;

constructor TghSQLTable.Create(AConn: TghSQLConnector);
begin
  inherited Create;

  FConnector := AConn;

  if Assigned(FConnector) then
    FConnector.Notify(Self, opInsert);

  FData := nil;
  FSelectColumns := '*';
  FUseRetaining := True;
  FEnforceConstraints := True;
  FErrors := TStringList.Create;
  FLinks := TghSQLTableList.Create(Self, True);
  FLinks.OnNewTable := @CallFoundTable;
  FLinks.OnFoundTable := @CallFoundTable;
end;

constructor TghSQLTable.Create(AConn: TghSQLConnector; const ATableName: string);
begin
  Create(AConn);
  FTableName := ATableName;
end;

constructor TghSQLTable.Create(AConn: TghSQLConnector; const ATableName: string;
  AOwnerTable: TghSQLTable);
begin
  Create(AConn, ATableName);
  FOwnerTable := AOwnerTable;
end;

destructor TghSQLTable.Destroy;
begin
  FErrors.Free;
  FLinks.Free;
  FData.Free;
  if Assigned(FConnector) then
    FConnector.Notify(Self, opRemove);
  inherited Destroy;
end;

procedure TghSQLTable.Assign(ASource: TghSQLStatement);
var
  Table: TghSQLTable;
begin
  inherited Assign(ASource);
  if ASource is TghSQLTable then
  begin
    Table := TghSQLTable(ASource);
    FSelectColumns := Table.FSelectColumns;
    FConditions := Table.FConditions;
    FOrderBy := Table.FOrderBy;
    FTableName := Table.FTableName;
    FReuse := Table.FReuse;
  end;
end;

procedure TghSQLTable.Clear;
begin
  inherited Clear;
  FSelectColumns := '*';
  FConditions := '';
  FOrderBy := '';
end;

function TghSQLTable.Close: TghSQLTable;
begin
  Result := Self;
  Clear;
  if Active then
  begin
    FData.Close;
    FreeAndNil(FData);
  end;
end;

function TghSQLTable.Open: TghSQLTable;
var
  SC: TghSQLClient;
begin
  DoBeforeOpen;
  FreeAndNil(FData);

  SC := TghSQLClient.Create(FConnector);
  try
    try
      SC.Assign(Self);
      // check if user is using your own script
      if FScript.Count = 0 then
      begin
        SC.Script.Clear;
        SC.Script.Add('select ' + FSelectColumns + ' from ' + FTableName);
        SC.Script.Add('where 1=1');
        if FConditions <> '' then
          SC.Script.Add('and ' + FConditions);
        if FOrderBy <> '' then
          SC.Script.Add('order by ' + FOrderBy);
      end;
      SC.Open(FData, nil);
    except
      FreeAndNil(FData);
      raise;
    end;
  finally
    SC.Free;
  end;
  Result := Self;
  DoAfterOpen;
end;

function TghSQLTable.Insert: TghSQLTable;
begin
  if not Active then
    Self.Where('1=2').Open;
  FData.Insert;
  SetDefaultValues;
  Result := Self;
end;

function TghSQLTable.Append: TghSQLTable;
begin
  if not Active then
    Self.Where('1=2').Open;
  FData.Append;
  SetDefaultValues;
  Result := Self;
end;

function TghSQLTable.Edit: TghSQLTable;
begin
  CheckData;
  FData.Edit;
  Result := Self;
end;

function TghSQLTable.Post: TghSQLTable;
begin
  CheckData;
  FErrors.Clear;
  DoBeforePost;
  if CheckValues then
  begin
    FData.Post;
    FErrors.Clear;
  end;
  DoAfterPost;
  Result := Self;
end;

function TghSQLTable.Cancel: TghSQLTable;
begin
  CheckData;
  FData.Cancel;
  FErrors.Clear;
  Result := Self;
end;

function TghSQLTable.Delete: TghSQLTable;
begin
  CheckData;
  FData.Delete;
  Result := Self;
end;

function TghSQLTable.DeleteAll: TghSQLTable;
begin
  CheckData;
  while not FData.EOF do
    FData.Delete;
  Result := Self;
end;

function TghSQLTable.Commit: TghSQLTable;
begin
  CheckData;
  InternalCommit(FUseRetaining);
  Result := Self;
end;

function TghSQLTable.CommitRetaining: TghSQLTable;
begin
  CheckData;
  InternalCommit(True);
  Result := Self;
end;

function TghSQLTable.Rollback: TghSQLTable;
begin
  CheckData;
  InternalRollback(False);
  Result := Self;
end;

function TghSQLTable.RollbackRetaining: TghSQLTable;
begin
  CheckData;
  InternalRollback(True);
  Result := Self;
end;

function TghSQLTable.Refresh: TghSQLTable;
begin
  CheckData;
  FData.Close;
  FData.Open;
  Result := Self;
end;

function TghSQLTable.First: TghSQLTable;
begin
  CheckData;
  FData.First;
  Result := Self;
end;

function TghSQLTable.Prior: TghSQLTable;
begin
  CheckData;
  FData.Prior;
  Result := Self;
end;

function TghSQLTable.Next: TghSQLTable;
begin
  CheckData;
  FData.Next;
  Result := Self;
end;

function TghSQLTable.Last: TghSQLTable;
begin
  CheckData;
  FData.Last;
  Result := Self;
end;

function TghSQLTable.Select(const AColumnNames: string): TghSQLTable;
begin
  FSelectColumns := AColumnNames;
  Result := Self;
end;

function TghSQLTable.Where(const AConditions: string): TghSQLTable;
begin
  FConditions := AConditions;
  Result := Self;
end;

function TghSQLTable.Where(const AConditionsFmt: string; AArgs: array of const): TghSQLTable;
begin
  Result := Self.Where(Format(AConditionsFmt, AArgs));
end;

function TghSQLTable.OrderBy(const AColumnNames: string): TghSQLTable;
begin
  FOrderBy := AColumnNames;
  Result := Self;
end;

function TghSQLTable.GetColumns: TghDataColumns;
begin
  CheckData;
  Result := FData.Fields;
end;

function TghSQLTable.HasErrors: Boolean;
begin
  Result := FErrors.Count > 0;
end;

function TghSQLTable.GetErrors: TStrings;
begin
  Result := FErrors;
end;

procedure TghSQLTable.SetDataRow(ADataRow: TghDataRow);
var
  I: Integer;
  Col: TghDataColumn;
  Par: TParam;
begin
  for I := 0 to ADataRow.Count-1 do
  begin
    Par := ADataRow.Items[I];
    Col := GetColumns.FindField(Par.Name);
    if not Assigned(Col) then
      Continue;
    if Par.IsNull then
      Col.Clear
    else
      Col.Value := Par.Value;
  end;
end;

{ TghSQLTableList }

function TghSQLTableList.GetTables(const ATableName: string): TghSQLTable;
begin
  if ATableName = '' then
    raise EghSQLError.Create(Self, 'TableName not defined.');

  Result := FindByName(ATableName);
  if (Result = nil) and FLocked then
    raise EghSQLError.Create(Self, 'Table not found.');

  if (Result = nil) or (Result.Active and (not Result.Reuse)) then
  begin
    Result := TghSQLTable.Create(nil, ATableName);
    Result.Reuse := False;
    Add(Result);
    DoNewTable(Result);
  end;
end;

procedure TghSQLTableList.DoNewTable(ATable: TghSQLTable);
begin
  if Assigned(FOnNewTable) then
    FOnNewTable(Self, ATable);
end;

procedure TghSQLTableList.DoFoundTable(ATable: TghSQLTable);
begin
  if Assigned(FOnFoundTable) then
    FOnFoundTable(Self, ATable);
end;

constructor TghSQLTableList.Create(AOwnerTable: TghSQLTable; AFreeObjects: Boolean);
begin
  inherited Create(AFreeObjects);
  FLocked := False;
  FOwnerTable := AOwnerTable;
end;

destructor TghSQLTableList.Destroy;
var
  I: Integer;
begin
  if Self.FreeObjects then
  begin
    for I := 0 to Count -1 do
    begin
      with Items[I] do
      begin
        // FIRST, close table!
        Close;
        // now, disable notifications to Connector
        Connector := nil;
      end;
    end;
  end;

  inherited Destroy;
end;

function TghSQLTableList.FindByName(const AName: string): TghSQLTable;
var
  I: Integer;
  Table: TghSQLTable;
begin
  Result := nil;
  for I := 0 to Count-1 do
  begin
    Table := Items[I];
    // TODO: Check if Table.Reuse?
    if (Table.TableName = AName) then
    begin
      Result := Table;
      DoFoundTable(Result);
      Exit;
    end;
  end;
end;

procedure TghSQLTableList.Lock;
begin
  FLocked := True;
end;

procedure TghSQLTableList.UnLock;
begin
  FLocked := False;
end;

{ TghSQLLib }

constructor TghSQLLib.Create(var AConnector: TghSQLConnector);
begin
  inherited Create;
  FConnector := AConnector;
end;

function TghSQLLib.GetLastAutoIncValue: NativeInt;
begin
  Result := -1;
end;

{ TghSQLConnector }

function TghSQLConnector.GetConnected: Boolean;
begin
  try
    Result := FLib.Connected;
  except
    on e: Exception do
      raise EghSQLError.Create(e.Message);
  end;
end;

procedure TghSQLConnector.CallNewTable(Sender: TObject; ATable: TghSQLTable);
begin
  ATable.Connector := Self;
end;

constructor TghSQLConnector.Create(ALib: TghSQLLibClass);
begin
  inherited Create;
  FTables := TghSQLTableList.Create(nil, False);
  FTables.OnNewTable := @CallNewTable;
  SetLibClass(ALib);
end;

destructor TghSQLConnector.Destroy;
var
  Table: TghSQLTable;
begin
  while FTables.Count > 0 do
  begin
    Table := FTables.Items[0];
    Table.Close;
    Table.Connector := nil;
    Notify(Table, opRemove);
    Table.Free;
  end;
  FTables.Free;
  FLib.Free;
  inherited Destroy;
end;

procedure TghSQLConnector.SetLibClass(ALib: TghSQLLibClass);
begin
  if not Assigned(ALib) then
    raise EghSQLError.Create('Lib not assigned.');

  if Assigned(FLib) then
    FLib.Free;
  FLib := ALib.Create(Self);
end;

procedure TghSQLConnector.Connect;
begin
  try
    FLib.Connect;
  except
    on e: Exception do
      raise EghSQLError.Create(e.Message);
  end;
end;

procedure TghSQLConnector.Disconnect;
begin
  try
    if Connected then
      FLib.Disconnect;
  except
    on e: Exception do
      raise EghSQLError.Create(e.Message);
  end;
end;

procedure TghSQLConnector.StartTransaction;
begin
  try
    if FTransCount = 0 then
    begin
      FLib.StartTransaction;
    end;
    Inc(FTransCount);
  except
    on e: Exception do
      raise EghSQLError.Create(e.Message);
  end;
end;

function TghSQLConnector.InTransaction: Boolean;
begin
  Result := (FTransCount > 0) or FLib.InTransaction;
end;

procedure TghSQLConnector.Commit;
begin
  if FTransCount = 0 then
    Exit;
  try
    if FTransCount = 1 then
      FLib.Commit;
    Dec(FTransCount);
  except
    on e: Exception do
      raise EghSQLError.Create(e.Message);
  end;
end;

procedure TghSQLConnector.CommitRetaining;
begin
  if FTransCount = 0 then
    Exit;
  try
    if FTransCount = 1 then
      FLib.CommitRetaining;
    Dec(FTransCount);
  except
    on e: Exception do
      raise EghSQLError.Create(e.Message);
  end;
end;

procedure TghSQLConnector.Rollback;
begin
  if FTransCount = 0 then
    Exit;
  try
    if FTransCount = 1 then
      FLib.Rollback;
    Dec(FTransCount);
  except
    on e: Exception do
      raise EghSQLError.Create(e.Message);
  end;
end;

procedure TghSQLConnector.RollbackRetaining;
begin
  if FTransCount = 0 then
    Exit;
  try
    if FTransCount = 1 then
      FLib.RollbackRetaining;
    Dec(FTransCount);
  except
    on e: Exception do
      raise EghSQLError.Create(e.Message);
  end;
end;

procedure TghSQLConnector.Notify(ATable: TghSQLTable; AOperation: TOperation);
begin
  case AOperation of
    opInsert:
      begin
        if FTables.IndexOf(ATable) = -1 then
          FTables.Add(ATable);
      end;
    opRemove: FTables.Remove(ATable);
  end;
end;

initialization
   TghSQLTable.ClassInitialization;

finalization
   TghSQLTable.ClassFinalization;

end.
