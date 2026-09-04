unit DW.Androidapi.JNI.ReflectArray;

{*******************************************************}
{                                                       }
{                      Kastri                           }
{                                                       }
{         Delphi Worlds Cross-Platform Library          }
{                                                       }
{  Copyright 2020-2025 Dave Nottage under MIT license   }
{  which is located in the root folder of this library  }
{                                                       }
{*******************************************************}

{ TimeLapse addition.

  Reading a Java ARRAY that arrives as a bare Object - which is what
  CameraCharacteristics.get returns for int[] and float[] values - has no safe
  route through the JNI bridge:

    class function TJavaArray<T>.Wrap(const AnArray: TJavaBasicArray)

  Wrap expects a Delphi OBJECT, not a handle. Delphi silently accepts a Pointer
  where a class reference is expected, so passing the handle compiles - and Wrap
  then reads its Handle field at an offset inside a native Java structure. The
  garbage it finds surfaces much later as an access violation in
  TJavaBasicArray.ToPointer, far from the cause.

  java.lang.reflect.Array is the way out. Its static methods take the array as
  an Object and an index, so nothing has to be wrapped: each element is read
  through an ordinary JNI call. Slower than a bulk copy, and entirely beside the
  point for the handful of values a camera reports. }

interface

uses
  Androidapi.JNIBridge, Androidapi.JNI.JavaTypes;

type
  JReflectArray = interface;

  JReflectArrayClass = interface(JObjectClass)
    ['{2B4A6F0C-7D51-4E38-9A62-0C5E3B1F84D7}']
    {class} function getLength(&array: JObject): Integer; cdecl;
    {class} function getInt(&array: JObject; index: Integer): Integer; cdecl;
    {class} function getFloat(&array: JObject; index: Integer): Single; cdecl;
    {class} function getLong(&array: JObject; index: Integer): Int64; cdecl;
  end;

  [JavaSignature('java/lang/reflect/Array')]
  JReflectArray = interface(JObject)
    ['{9C71E5A8-3D02-4B67-8F14-6A2D0E93C5B1}']
  end;
  TJReflectArray = class(TJavaGenericImport<JReflectArrayClass, JReflectArray>) end;

/// <summary>
///   Reads a Java int[] arriving as an Object. Returns an empty array when the
///   object is nil or cannot be read: a value that will not be read is not a
///   reason to bring anything down.
/// </summary>
function ReadIntArray(const AObject: JObject): TArray<Integer>;

/// <summary>Reads a Java float[] arriving as an Object.</summary>
function ReadFloatArray(const AObject: JObject): TArray<Single>;

implementation

uses
  System.SysUtils;

function ReadIntArray(const AObject: JObject): TArray<Integer>;
var
  I, LCount: Integer;
begin
  Result := nil;
  if AObject = nil then
    Exit;
  try
    LCount := TJReflectArray.JavaClass.getLength(AObject);
    SetLength(Result, LCount);
    for I := 0 to LCount - 1 do
      Result[I] := TJReflectArray.JavaClass.getInt(AObject, I);
  except
    on E: Exception do
      Result := nil;
  end;
end;

function ReadFloatArray(const AObject: JObject): TArray<Single>;
var
  I, LCount: Integer;
begin
  Result := nil;
  if AObject = nil then
    Exit;
  try
    LCount := TJReflectArray.JavaClass.getLength(AObject);
    SetLength(Result, LCount);
    for I := 0 to LCount - 1 do
      Result[I] := TJReflectArray.JavaClass.getFloat(AObject, I);
  except
    on E: Exception do
      Result := nil;
  end;
end;

end.
