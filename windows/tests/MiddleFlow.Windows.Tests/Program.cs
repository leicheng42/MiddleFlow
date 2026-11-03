using System.Runtime.InteropServices;
using MiddleFlow.Core.Interop;

var failures = new List<string>();

void Check(bool condition, string message)
{
    if (!condition)
    {
        failures.Add(message);
    }
}

var is64Bit = IntPtr.Size == 8;
var inputSize = Marshal.SizeOf<Win32Input.INPUT>();
var mouseSize = Marshal.SizeOf<Win32Input.MOUSEINPUT>();
var keyboardSize = Marshal.SizeOf<Win32Input.KEYBDINPUT>();
var unionOffset = Marshal.OffsetOf<Win32Input.INPUT>(nameof(Win32Input.INPUT.U)).ToInt64();

Console.WriteLine(
    $"INPUT={inputSize}, MOUSEINPUT={mouseSize}, KEYBDINPUT={keyboardSize}, " +
    $"unionOffset={unionOffset}, process64={is64Bit}");

Check(
    inputSize == (is64Bit ? 40 : 28),
    $"INPUT must match Win32 layout (expected {(is64Bit ? 40 : 28)}).");
Check(
    mouseSize == (is64Bit ? 32 : 24),
    $"MOUSEINPUT must match Win32 layout (expected {(is64Bit ? 32 : 24)}).");
Check(
    keyboardSize == (is64Bit ? 24 : 16),
    $"KEYBDINPUT must match Win32 layout (expected {(is64Bit ? 24 : 16)}).");
Check(
    unionOffset == (is64Bit ? 8 : 4),
    $"INPUT union must be aligned after the type field (expected {(is64Bit ? 8 : 4)}).");

if (failures.Count > 0)
{
    Console.Error.WriteLine("Win32 input layout test failed:");
    foreach (var failure in failures)
    {
        Console.Error.WriteLine(" - " + failure);
    }
    return 1;
}

Console.WriteLine("Windows input layout test passed.");
return 0;
