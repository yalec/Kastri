unit DW.Camera;

{*******************************************************}
{                                                       }
{                      Kastri                           }
{                                                       }
{         Delphi Worlds Cross-Platform Library          }
{                                                       }
{  Copyright 2020-2026 Dave Nottage under MIT license   }
{  which is located in the root folder of this library  }
{                                                       }
{*******************************************************}

interface

uses
  // RTL
  System.Classes, System.Types, System.Messaging, System.Sensors,
  // FMX
  FMX.Controls, FMX.Media, FMX.Graphics,
  // DW
  DW.Types;

type
  TMetadataOption = (GPS, Orientation);

  TMetadataOptions = set of TMetadataOption;

  TFaceDetectMode = (None, Simple, Full);

  TFaceDetectModes = set of TFaceDetectMode;

  TFace = record
    Bounds: TRectF;
    LeftEyePosition: TPointF;
    MouthPosition: TPointF;
    RightEyePosition: TPointF;
    Score: Integer;
  end;

  TFaces = array of TFace;

  TDetectedFacesEvent = procedure(Sender: TObject; const ImageStream: TStream; const Faces: TFaces) of object;

  TFrameAvailableEvent = procedure(Sender: TObject; const Frame: TBitmap) of object;
  TImageAvailableEvent = procedure(Sender: TObject; const ImageStream: TStream) of object;

  TCamera = class;

  TCustomPlatformCamera = class(TObject)
  private
    FCamera: TCamera;
    FCameraPosition: TDevicePosition;
    FContinuousCapture: Boolean;
    FExposure: Single;
    FFaceDetectMode: TFaceDetectMode;
    FFlashMode: TFlashMode;
    FWasActive: Boolean;
    procedure ApplicationEventMessageHandler(const Sender: TObject; const M: TMessage);
    function GetExposure: Single;
    function GetIsActive: Boolean;
    function GetCameraPosition: TDevicePosition;
    function GetMetadataOptions: TMetadataOptions;
    procedure ResetCamera;
    procedure ResignCamera;
    procedure RestoreCamera;
    procedure SetCameraPosition(const Value: TDevicePosition);
    procedure SetContinuousCapture(const Value: Boolean);
    procedure SetExposure(const Value: Single);
    procedure SetIsActive(const Value: Boolean);
  protected
    FAvailableFaceDetectModes: TFaceDetectModes;
    FAvailableControlAEModes: TArray<Integer>;
    FIsActive: Boolean;
    FLastError: string;
    FIsCapturing: Boolean;
    FIsFaceDetectActive: Boolean;
    FIsSwapping: Boolean;
    procedure CameraSettingChanged; virtual;
    function CanControlExposure: Boolean; virtual;
    procedure CaptureImage;
    procedure CloseCamera; virtual;
    procedure ContinuousCaptureChanged; virtual;
    procedure DoAuthorizationStatus(const AStatus: TAuthorizationStatus);
    procedure DoCaptureImage; virtual;
    procedure DoCapturedImage(const AImageStream: TStream);
    procedure DoDetectedFaces(const AImageStream: TStream; const AFaces: TFaces);
    procedure DoFrameAvailable(const AFrame: TBitmap);
    procedure DoStatusChange;
    // TimeLapse: sizes the sensor offers. Empty until the camera is open, since
    // only the device can say what it supports.
    function GetAvailableSizes: TArray<TSize>; virtual;
    // TimeLapse: the exposure and sensitivity the sensor actually accepts.
    // Zero means the platform cannot say, which is not the same as "no limit":
    // callers must treat it as unknown rather than as an open range.
    function GetMinExposureTime: Int64; virtual;
    function GetMaxExposureTime: Int64; virtual;
    function GetMinISO: Integer; virtual;
    function GetMaxISO: Integer; virtual;
    // TimeLapse: the largest digital zoom the sensor accepts. 1 means no zoom is
    // available, which is different from "not asked yet".
    function GetMaxZoom: Single; virtual;
    // TimeLapse: what the camera actually used for the last frame it completed.
    // Zero means nothing has been measured yet.
    procedure SetMeasuredExposure(const AExposureTime: Int64;
      const AISO: Integer; const AWhiteBalanceMode: Integer);
    // TimeLapse: white balance modes this sensor really offers. Empty when the
    // question could not be answered - offer nothing rather than a mode that
    // will be ignored without a word.
    function GetAvailableWhiteBalanceModes: TArray<Integer>; virtual;
    function GetCameraOrientation: Integer; virtual; //!!!!
    function GetFlashMode: TFlashMode;
    // TimeLapse: size the application asked for, (0,0) when it asked for nothing.
    function RequestedViewSize: TSize;
    function GetPreviewControl: TControl; virtual;
    function GetResolutionHeight: Integer; virtual;
    function GetResolutionWidth: Integer; virtual;
    function HasControlAEMode(const AMode: Integer): Boolean;
    procedure InternalSetActive(const AValue: Boolean);
    // TimeLapse: the camera can fail to open, and the failure was only written to
    // the log. An app then shows a frozen counter with nothing to explain it.
    procedure SetLastError(const AError: string);
    procedure InternalSetExposure(const AValue: Single);
    procedure OpenCamera; virtual;
    procedure QueueAuthorizationStatus(const AStatus: TAuthorizationStatus);
    procedure RequestPermission; virtual; abstract;
    procedure SetFaceDetectMode(const Value: TFaceDetectMode); virtual;
    procedure SetFlashMode(const Value: TFlashMode);
    procedure StartCapture; virtual;
    procedure StopCapture; virtual;
    property IsActive: Boolean read GetIsActive write SetIsActive;
    // TimeLapse: reason the camera refused to open, empty when all is well.
    property LastError: string read FLastError;
    property Camera: TCamera read FCamera;
    property CameraPosition: TDevicePosition read GetCameraPosition write SetCameraPosition;
    property ContinuousCapture: Boolean read FContinuousCapture write SetContinuousCapture;
    property Exposure: Single read GetExposure write SetExposure;
    property FaceDetectMode: TFaceDetectMode read FFaceDetectMode write SetFaceDetectMode;
    property FlashMode: TFlashMode read GetFlashMode write SetFlashMode;
    property MetadataOptions: TMetadataOptions read GetMetadataOptions;
  public
    constructor Create(const ACamera: TCamera); virtual;
    destructor Destroy; override;
    property PreviewControl: TControl read GetPreviewControl;
  end;

  TCamera = class(TObject)
  private
    FAuthorizationStatus: TAuthorizationStatus;
    FLocation: TLocationCoord2D;
    FMetadataOptions: TMetadataOptions;
    FPlatformCamera: TCustomPlatformCamera;
    FRequestedSize: TSize;
    FRequestedExposureTime: Int64;
    FRequestedISO: Integer;
    FRequestedZoom: Single;
    FRequestedWhiteBalanceMode: Integer;
    FMeasuredExposureTime: Int64;
    FMeasuredISO: Integer;
    FMeasuredWhiteBalanceMode: Integer;
    FLockAfterFirstFrame: Boolean;
    FExposureLocked: Boolean;
    FOnAuthorizationStatus: TAuthorizationStatusEvent;
    FOnDetectedFaces: TDetectedFacesEvent;
    FOnFrameAvailable: TFrameAvailableEvent;
    FOnImageCaptured: TImageAvailableEvent;
    FOnStatusChange: TNotifyEvent;
    function GetIsActive: Boolean;
    function GetLastError: string;
    function GetAvailableFaceDetectModes: TFaceDetectModes;
    function GetCameraPosition: TDevicePosition;
    function GetContinuousCapture: Boolean;
    function GetExposure: Single;
    function GetFaceDetectMode: TFaceDetectMode;
    function GetFlashMode: TFlashMode;
    function GetPreviewControl: TControl;
    function GetResolutionHeight: Integer;
    function GetResolutionWidth: Integer;
    procedure SetContinuousCapture(const Value: Boolean);
    procedure SetIsActive(const Value: Boolean);
    procedure SetCameraPosition(const Value: TDevicePosition);
    procedure SetExposure(const Value: Single);
    procedure SetFaceDetectMode(const Value: TFaceDetectMode);
    procedure SetFlashMode(const Value: TFlashMode);
    function GetCameraOrientation: Integer; //!!!!
    function GetIncludeLocation: Boolean;
    procedure SetIncludeLocation(const Value: Boolean);
    function GetIsCapturing: Boolean;
    procedure SetRequestedZoom(const Value: Single);
    procedure SetRequestedWhiteBalanceMode(const Value: Integer);
  protected
    procedure DoAuthorizationStatus(const AStatus: TAuthorizationStatus);
    procedure DoCapturedImage(const AImageStream: TStream);
    procedure DoDetectedFaces(const AImageStream: TStream; const AFaces: TFaces);
    procedure DoFrameAvailable(const AFrame: TBitmap);
    procedure DoStatusChange;
  public
    constructor Create;
    destructor Destroy; override;
    /// <summary>
    ///   Captures a still image, returned in OnImageCaptured
    /// </summary>
    procedure CaptureImage;
    /// <summary>
    ///   TimeLapse: sizes this camera can capture at. Empty until the camera is
    ///   open - the list comes from the sensor, not from a guess.
    /// </summary>
    function AvailableSizes: TArray<TSize>;
    /// <summary>
    ///   TimeLapse: size to capture at. Set it to (0,0), the default, to keep the
    ///   maximum the sensor offers. A size the sensor does not offer is ignored,
    ///   and the maximum used instead. Read when the camera opens, so set it
    ///   BEFORE setting IsActive.
    ///   The maximum is not always what an application wants: a time-lapse aimed
    ///   at a 1080p video has no use for 12 megapixel stills, which cost storage,
    ///   write time and heat.
    /// </summary>
    property RequestedSize: TSize read FRequestedSize write FRequestedSize;
    /// <summary>
    ///   TimeLapse: exposure time in NANOSECONDS. Zero, the default, keeps the
    ///   platform's own choice. A value outside the sensor's range is clamped to
    ///   it rather than refused - but read MaxExposureTime first and show the
    ///   real bound, because clamping in silence hides why a night shot came out
    ///   dark.
    /// </summary>
    property RequestedExposureTime: Int64 read FRequestedExposureTime
      write FRequestedExposureTime;
    /// <summary>
    ///   TimeLapse: ISO sensitivity. Zero, the default, keeps the platform's own
    ///   choice. Clamped to the sensor's range like the exposure time.
    /// </summary>
    property RequestedISO: Integer read FRequestedISO write FRequestedISO;
    /// <summary>
    ///   TimeLapse: bounds the sensor accepts. Zero means unknown, which is not
    ///   the same as unbounded.
    /// </summary>
    function MinExposureTime: Int64;
    function MaxExposureTime: Int64;
    function MinISO: Integer;
    function MaxISO: Integer;
    /// <summary>
    ///   TimeLapse: digital zoom factor. 1 (the default) frames the whole
    ///   sensor. Applied by cropping the sensor region, so it takes effect on
    ///   the preview as well as on stills - the point being that what you see is
    ///   what you get. Clamped to MaxZoom.
    /// </summary>
    property RequestedZoom: Single read FRequestedZoom write SetRequestedZoom;
    /// <summary>
    ///   TimeLapse: white balance, one of CameraMetadata.CONTROL_AWB_MODE_*.
    ///   Zero, the default, leaves the camera's own automatic mode.
    /// </summary>
    property RequestedWhiteBalanceMode: Integer read FRequestedWhiteBalanceMode
      write SetRequestedWhiteBalanceMode;
    /// <summary>
    ///   TimeLapse: freeze the exposure on what the camera chose for the first
    ///   completed frame, and reuse it for every frame after.
    ///
    ///   This is THE time-lapse setting. Left to itself, automatic exposure
    ///   re-decides on every frame: the finished video flickers, and no amount
    ///   of editing takes that out. Locking after the first frame keeps the
    ///   convenience of automatic metering for the shot that sets the scene,
    ///   then holds it steady for the hours that follow.
    ///
    ///   Nothing happens until a frame completes, so a lock asked for before
    ///   the camera has seen anything simply waits.
    /// </summary>
    property LockAfterFirstFrame: Boolean read FLockAfterFirstFrame
      write FLockAfterFirstFrame;
    /// <summary>TimeLapse: True once the values have been captured and held.</summary>
    property ExposureLocked: Boolean read FExposureLocked;
    /// <summary>TimeLapse: exposure the camera actually used, in nanoseconds.</summary>
    property MeasuredExposureTime: Int64 read FMeasuredExposureTime;
    /// <summary>TimeLapse: sensitivity the camera actually used.</summary>
    property MeasuredISO: Integer read FMeasuredISO;
    /// <summary>TimeLapse: records what the camera used. Called by the platform.</summary>
    procedure SetMeasured(const AExposureTime: Int64; const AISO: Integer;
      const AWhiteBalanceMode: Integer);
    /// <summary>Releases the lock, so metering resumes.</summary>
    procedure UnlockExposure;
    /// <summary>TimeLapse: largest zoom the sensor accepts; 1 means none.</summary>
    function MaxZoom: Single;
    /// <summary>TimeLapse: white balance modes the sensor really offers.</summary>
    function AvailableWhiteBalanceModes: TArray<Integer>;
    /// <summary>
    ///   Determines whether the camera supports control of exposure
    /// </summary>
    function CanControlExposure: Boolean;
    /// <summary>
    ///   Requests camera permissions, returned in OnAuthorizationStatus
    /// </summary>
    procedure RequestPermission;
    /// <summary>
    ///   Modes that are available for face detection
    /// </summary>
    property AvailableFaceDetectModes: TFaceDetectModes read GetAvailableFaceDetectModes;
    /// <summary>
    ///   Current authorization status
    /// </summary>
    property AuthorizationStatus: TAuthorizationStatus read FAuthorizationStatus;
    property CameraOrientation: Integer read GetCameraOrientation; //!!!!
    /// <summary>
    ///   Position of the currently selected camera, i.e. Front or Back
    /// </summary>
    property CameraPosition: TDevicePosition read GetCameraPosition write SetCameraPosition;
    property ContinuousCapture: Boolean read GetContinuousCapture write SetContinuousCapture;
    /// <summary>
    ///   //
    /// </summary>
    property Exposure: Single read GetExposure write SetExposure;
    /// <summary>
    ///   Currently selected mode of face detection
    /// </summary>
    property FaceDetectMode: TFaceDetectMode read GetFaceDetectMode write SetFaceDetectMode;
    /// <summary>
    ///   Currently selected flash mode
    /// </summary>    
    property FlashMode: TFlashMode read GetFlashMode write SetFlashMode;
    /// <summary>
    ///   Include location data with the captured image. See also Location property
    /// </summary>
    property IncludeLocation: Boolean read GetIncludeLocation write SetIncludeLocation;
    /// <summary>
    ///   Signifies whether or not the camera is active
    /// </summary>
    property IsActive: Boolean read GetIsActive write SetIsActive;
    /// <summary>
    ///   TimeLapse: why the camera refused to open; empty when all is well.
    ///   Opening is asynchronous, so a failure used to reach only the log, and an
    ///   application had no way of telling a slow start from a dead camera.
    /// </summary>
    property LastError: string read GetLastError;
    /// <summary>
    ///   Signifies whether or not the camera is capturing video
    /// </summary>
    property IsCapturing: Boolean read GetIsCapturing;
    /// <summary>
    ///   Location data to be included with the captured image.
    /// </summary>
    /// <remarks>
    ///   Set this value before calling CaptureImage
    /// </remarks>
    property Location: TLocationCoord2D read FLocation write FLocation;
    /// <summary>
    ///   Include location data with the captured image. See also Location property
    /// </summary>
    property MetadataOptions: TMetadataOptions read FMetadataOptions write FMetadataOptions;
    /// <summary>
    ///   The control in which to show the camera preview
    /// </summary>      
    property PreviewControl: TControl read GetPreviewControl;
    /// <summary>
    ///   Vertical resolution
    /// </summary>      
    property ResolutionHeight: Integer read GetResolutionHeight;
    /// <summary>
    ///   Horizontal resolution
    /// </summary>   
    property ResolutionWidth: Integer read GetResolutionWidth;
    /// <summary>
    ///   Event fired when an authorization request has returned
    /// </summary>
    property OnAuthorizationStatus: TAuthorizationStatusEvent read FOnAuthorizationStatus write FOnAuthorizationStatus;
    /// <summary>
    ///   Event fired when faces are detected
    /// </summary>
    property OnDetectedFaces: TDetectedFacesEvent read FOnDetectedFaces write FOnDetectedFaces;
    /// <summary>
    ///   Event fired when a frame is available
    /// </summary>
    property OnFrameAvailable: TFrameAvailableEvent read FOnFrameAvailable write FOnFrameAvailable;
    /// <summary>
    ///   Event fired when a still image is captured
    /// </summary>
    property OnImageCaptured: TImageAvailableEvent read FOnImageCaptured write FOnImageCaptured;
    /// <summary>
    ///   Event fired when the status of the camera changes
    /// </summary>
    property OnStatusChange: TNotifyEvent read FOnStatusChange write FOnStatusChange;
  end;

implementation

uses
  // RTL
  System.Math,
  // FMX
  FMX.Platform,
  // DW
{$IF Defined(ANDROID)}
  DW.Camera.Android,
{$ENDIF}
{$IF Defined(IOS)}
  DW.Camera.iOS, DW.iOSapi.Helpers,
{$ENDIF}
  DW.OSLog,
  DW.Messaging;

type
  TPlatformCameraDefault = class(TCustomPlatformCamera)
  private
    FPreviewControl: TControl;
  protected
    function GetPreviewControl: TControl; override;
  public
    constructor Create(const ACamera: TCamera); override;
    destructor Destroy; override;
  end;

{$IF Defined(MSWINDOWS)}
   TPlatformCamera = TPlatformCameraDefault;
{$ENDIF}

{ TPlatformCameraDefault }

constructor TPlatformCameraDefault.Create(const ACamera: TCamera);
begin
  inherited;
  FPreviewControl := TControl.Create(nil);
end;

destructor TPlatformCameraDefault.Destroy;
begin
  FPreviewControl.Free;
  inherited;
end;

function TPlatformCameraDefault.GetPreviewControl: TControl;
begin
  Result := FPreviewControl;
end;

{ TCustomPlatformCamera }

constructor TCustomPlatformCamera.Create(const ACamera: TCamera);
begin
  inherited Create;
  FCamera := ACamera;
  TMessageManager.DefaultManager.SubscribeToMessage(TApplicationEventMessage, ApplicationEventMessageHandler);
end;

destructor TCustomPlatformCamera.Destroy;
begin
  TMessageManager.DefaultManager.Unsubscribe(TApplicationEventMessage, ApplicationEventMessageHandler);
  inherited;
end;

procedure TCustomPlatformCamera.SetLastError(const AError: string);
begin
  FLastError := AError;
end;

procedure TCustomPlatformCamera.InternalSetActive(const AValue: Boolean);
begin
  FIsActive := AValue;
  TThread.Synchronize(nil,
    procedure
    begin
      DoStatusChange;
    end
  );
end;

procedure TCustomPlatformCamera.ApplicationEventMessageHandler(const Sender: TObject; const M: TMessage);
var
  LEvent: TApplicationEvent;
begin
  LEvent := TApplicationEventMessage(M).Value.Event;
  case LEvent of
    TApplicationEvent.EnteredBackground:
      ResignCamera;
    TApplicationEvent.BecameActive:
      RestoreCamera;
  end;
end;

function TCustomPlatformCamera.GetAvailableSizes: TArray<TSize>;
begin
  Result := nil;
end;

function TCustomPlatformCamera.GetMinExposureTime: Int64;
begin
  Result := 0;
end;

function TCustomPlatformCamera.GetMaxExposureTime: Int64;
begin
  Result := 0;
end;

function TCustomPlatformCamera.GetMinISO: Integer;
begin
  Result := 0;
end;

function TCustomPlatformCamera.GetMaxISO: Integer;
begin
  Result := 0;
end;

function TCustomPlatformCamera.GetMaxZoom: Single;
begin
  Result := 1;
end;

procedure TCustomPlatformCamera.SetMeasuredExposure(const AExposureTime: Int64;
  const AISO: Integer; const AWhiteBalanceMode: Integer);
begin
  FCamera.SetMeasured(AExposureTime, AISO, AWhiteBalanceMode);
end;

function TCustomPlatformCamera.GetAvailableWhiteBalanceModes: TArray<Integer>;
begin
  Result := nil;
end;

function TCustomPlatformCamera.RequestedViewSize: TSize;
begin
  Result := FCamera.RequestedSize;
end;

procedure TCustomPlatformCamera.CameraSettingChanged;
begin
  //
end;

function TCustomPlatformCamera.CanControlExposure: Boolean;
begin
  Result := False;
end;

procedure TCustomPlatformCamera.CaptureImage;
begin
  DoCaptureImage;
end;

procedure TCustomPlatformCamera.CloseCamera;
begin
  //
end;

procedure TCustomPlatformCamera.ContinuousCaptureChanged;
begin
  //
end;

procedure TCustomPlatformCamera.DoAuthorizationStatus(const AStatus: TAuthorizationStatus);
begin
  FCamera.DoAuthorizationStatus(AStatus);
end;

procedure TCustomPlatformCamera.DoCapturedImage(const AImageStream: TStream);
begin
  AImageStream.Position := 0;
  FCamera.DoCapturedImage(AImageStream);
end;

procedure TCustomPlatformCamera.DoCaptureImage;
begin
  //
end;

procedure TCustomPlatformCamera.DoDetectedFaces(const AImageStream: TStream; const AFaces: TFaces);
begin
  AImageStream.Position := 0;
  FCamera.DoDetectedFaces(AImageStream, AFaces);
end;

procedure TCustomPlatformCamera.DoFrameAvailable(const AFrame: TBitmap);
begin
  FCamera.DoFrameAvailable(AFrame);
end;

procedure TCustomPlatformCamera.DoStatusChange;
begin
  FCamera.DoStatusChange;
end;

function TCustomPlatformCamera.GetIsActive: Boolean;
begin
  Result := FIsActive;
end;

function TCustomPlatformCamera.GetMetadataOptions: TMetadataOptions;
begin
  Result := FCamera.MetadataOptions;
end;

function TCustomPlatformCamera.GetCameraOrientation: Integer;
begin
  Result := -1;
end;

function TCustomPlatformCamera.GetCameraPosition: TDevicePosition;
begin
  Result := FCameraPosition;
end;

function TCustomPlatformCamera.GetExposure: Single;
begin
  Result := FExposure;
end;

function TCustomPlatformCamera.GetFlashMode: TFlashMode;
begin
  Result := FFlashMode;
end;

function TCustomPlatformCamera.GetPreviewControl: TControl;
begin
  Result := nil;
end;

function TCustomPlatformCamera.GetResolutionHeight: Integer;
begin
  Result := 0;
end;

function TCustomPlatformCamera.GetResolutionWidth: Integer;
begin
  Result := 0;
end;

function TCustomPlatformCamera.HasControlAEMode(const AMode: Integer): Boolean;
var
  LMode: Integer;
begin
  Result := False;
  for LMode in FAvailableControlAEModes do
  begin
    if LMode = AMode then
    begin
      Result := True;
      Break;
    end;
  end;
end;

procedure TCustomPlatformCamera.OpenCamera;
begin
  //
end;

procedure TCustomPlatformCamera.QueueAuthorizationStatus(const AStatus: TAuthorizationStatus);
begin
  TThread.Queue(nil,
    procedure
    begin
      DoAuthorizationStatus(AStatus);
    end
  );
end;

procedure TCustomPlatformCamera.ResetCamera;
begin
  if FIsActive then
  begin
    CloseCamera;
    OpenCamera;
    FIsSwapping := False;
  end;
end;

procedure TCustomPlatformCamera.ResignCamera;
begin
  FWasActive := FIsActive;
  if FIsActive then
    CloseCamera;
end;

procedure TCustomPlatformCamera.RestoreCamera;
begin
  if FWasActive then
    OpenCamera;
end;

procedure TCustomPlatformCamera.SetIsActive(const Value: Boolean);
begin
  if FIsActive <> Value then
  begin
    if Value then
      OpenCamera
    else
      CloseCamera;
  end;
end;

procedure TCustomPlatformCamera.SetCameraPosition(const Value: TDevicePosition);
begin
  if Value <> FCameraPosition then
  begin
    FCameraPosition := Value;
    FIsSwapping := True;
    ResetCamera;
  end;
end;

procedure TCustomPlatformCamera.SetContinuousCapture(const Value: Boolean);
begin
  if FContinuousCapture <> Value then
  begin
    FContinuousCapture := Value;
    ContinuousCaptureChanged;
  end;
end;

procedure TCustomPlatformCamera.InternalSetExposure(const AValue: Single);
begin
  FExposure := AValue;
end;

procedure TCustomPlatformCamera.SetExposure(const Value: Single);
begin
  if FExposure <> Value then
  begin
    InternalSetExposure(Value);
    CameraSettingChanged;
  end;
end;

procedure TCustomPlatformCamera.SetFaceDetectMode(const Value: TFaceDetectMode);
begin
  FFaceDetectMode := Value;
end;

procedure TCustomPlatformCamera.SetFlashMode(const Value: TFlashMode);
begin
  if FFlashMode <> Value then
  begin
    FFlashMode := Value;
    CameraSettingChanged;
  end;
end;

procedure TCustomPlatformCamera.StartCapture;
begin
  //
end;

procedure TCustomPlatformCamera.StopCapture;
begin
  //
end;

{ TCamera }

constructor TCamera.Create;
begin
  inherited;
  FPlatformCamera := TPlatformCamera.Create(Self);
end;

destructor TCamera.Destroy;
begin
  FPlatformCamera.Free;
  inherited;
end;

procedure TCamera.DoAuthorizationStatus(const AStatus: TAuthorizationStatus);
begin
  FAuthorizationStatus := AStatus;
  if Assigned(FOnAuthorizationStatus) then
    FOnAuthorizationStatus(Self, FAuthorizationStatus);
end;

procedure TCamera.DoCapturedImage(const AImageStream: TStream);
begin
  if Assigned(FOnImageCaptured) then
    FOnImageCaptured(Self, AImageStream);
end;

procedure TCamera.DoDetectedFaces(const AImageStream: TStream; const AFaces: TFaces);
begin
  if Assigned(FOnDetectedFaces) then
    FOnDetectedFaces(Self, AImageStream, AFaces);
end;

procedure TCamera.DoFrameAvailable(const AFrame: TBitmap);
begin
  if Assigned(FOnFrameAvailable) then
    FOnFrameAvailable(Self, AFrame);
end;

procedure TCamera.DoStatusChange;
begin
  if Assigned(FOnStatusChange) then
    FOnStatusChange(Self);
end;

function TCamera.GetIncludeLocation: Boolean;
begin
  Result := TMetadataOption.GPS in FMetadataOptions;
end;

function TCamera.GetIsActive: Boolean;
begin
  Result := FPlatformCamera.IsActive;
end;

function TCamera.GetIsCapturing: Boolean;
begin
  Result := FPlatformCamera.FIsCapturing;
end;

function TCamera.GetAvailableFaceDetectModes: TFaceDetectModes;
begin
  Result := FPlatformCamera.FAvailableFaceDetectModes;
end;

function TCamera.GetCameraOrientation: Integer;
begin
  Result := FPlatformCamera.GetCameraOrientation;
end;

function TCamera.GetCameraPosition: TDevicePosition;
begin
  Result := FPlatformCamera.CameraPosition;
end;

function TCamera.GetContinuousCapture: Boolean;
begin
  Result := FPlatformCamera.ContinuousCapture;
end;

function TCamera.GetExposure: Single;
begin
  Result := FPlatformCamera.Exposure;
end;

function TCamera.GetFaceDetectMode: TFaceDetectMode;
begin
  Result := FPlatformCamera.FaceDetectMode;
end;

function TCamera.GetFlashMode: TFlashMode;
begin
  Result := FPlatformCamera.FlashMode;
end;

function TCamera.GetPreviewControl: TControl;
begin
  Result := FPlatformCamera.PreviewControl;
end;

function TCamera.GetResolutionHeight: Integer;
begin
  Result := FPlatformCamera.GetResolutionHeight;
end;

function TCamera.GetResolutionWidth: Integer;
begin
  Result := FPlatformCamera.GetResolutionWidth;
end;

procedure TCamera.RequestPermission;
begin
  FPlatformCamera.RequestPermission;
end;

procedure TCamera.SetIncludeLocation(const Value: Boolean);
begin
  if Value then
    Include(FMetadataOptions, TMetadataOption.GPS)
  else
    Exclude(FMetadataOptions, TMetadataOption.GPS);
end;

procedure TCamera.SetIsActive(const Value: Boolean);
begin
  FPlatformCamera.IsActive := Value;
end;

procedure TCamera.SetCameraPosition(const Value: TDevicePosition);
begin
  FPlatformCamera.CameraPosition := Value;
end;

procedure TCamera.SetContinuousCapture(const Value: Boolean);
begin
  FPlatformCamera.ContinuousCapture := Value;
end;

procedure TCamera.SetExposure(const Value: Single);
begin
  FPlatformCamera.Exposure := Value;
end;

procedure TCamera.SetFaceDetectMode(const Value: TFaceDetectMode);
begin
  FPlatformCamera.FaceDetectMode := Value;
end;

procedure TCamera.SetFlashMode(const Value: TFlashMode);
begin
  FPlatformCamera.FlashMode := Value;
end;

function TCamera.AvailableSizes: TArray<TSize>;
begin
  Result := FPlatformCamera.GetAvailableSizes;
end;

function TCamera.MinExposureTime: Int64;
begin
  Result := FPlatformCamera.GetMinExposureTime;
end;

function TCamera.MaxExposureTime: Int64;
begin
  Result := FPlatformCamera.GetMaxExposureTime;
end;

// TimeLapse: called from the camera thread on every completed frame. It must
// stay cheap and must not raise - hence no logging, no allocation.
procedure TCamera.SetMeasured(const AExposureTime: Int64; const AISO: Integer;
  const AWhiteBalanceMode: Integer);
begin
  // A frame that reports nothing usable teaches nothing: keep waiting rather
  // than lock onto zeros, which would produce black images for hours.
  if (AExposureTime <= 0) or (AISO <= 0) then
    Exit;
  FMeasuredExposureTime := AExposureTime;
  FMeasuredISO := AISO;
  FMeasuredWhiteBalanceMode := AWhiteBalanceMode;
  if FLockAfterFirstFrame and not FExposureLocked then
  begin
    FExposureLocked := True;
    // From here the measured values are used as if they had been requested, so
    // every later frame is exposed exactly like the first.
    FRequestedExposureTime := AExposureTime;
    FRequestedISO := AISO;
    if AWhiteBalanceMode > 0 then
      FRequestedWhiteBalanceMode := AWhiteBalanceMode;
    FPlatformCamera.CameraSettingChanged;
  end;
end;

procedure TCamera.UnlockExposure;
begin
  FExposureLocked := False;
  FRequestedExposureTime := 0;
  FRequestedISO := 0;
  FPlatformCamera.CameraSettingChanged;
end;

function TCamera.MaxZoom: Single;
begin
  Result := FPlatformCamera.GetMaxZoom;
end;

function TCamera.AvailableWhiteBalanceModes: TArray<Integer>;
begin
  Result := FPlatformCamera.GetAvailableWhiteBalanceModes;
end;

// TimeLapse: both settings are re-read on every request, so telling the platform
// that something changed is enough - no need to reopen anything.
procedure TCamera.SetRequestedZoom(const Value: Single);
begin
  if SameValue(FRequestedZoom, Value) then
    Exit;
  FRequestedZoom := Value;
  FPlatformCamera.CameraSettingChanged;
end;

procedure TCamera.SetRequestedWhiteBalanceMode(const Value: Integer);
begin
  if FRequestedWhiteBalanceMode = Value then
    Exit;
  FRequestedWhiteBalanceMode := Value;
  FPlatformCamera.CameraSettingChanged;
end;

function TCamera.MinISO: Integer;
begin
  Result := FPlatformCamera.GetMinISO;
end;

function TCamera.MaxISO: Integer;
begin
  Result := FPlatformCamera.GetMaxISO;
end;

function TCamera.CanControlExposure: Boolean;
begin
  Result := FPlatformCamera.CanControlExposure;
end;

function TCamera.GetLastError: string;
begin
  Result := FPlatformCamera.LastError;
end;

procedure TCamera.CaptureImage;
begin
  if IsActive then
    FPlatformCamera.CaptureImage;
end;

end.
