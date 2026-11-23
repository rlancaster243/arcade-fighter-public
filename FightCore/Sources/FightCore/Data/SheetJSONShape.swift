import Foundation

/// `sheet.json` is either a bare frame array (1x sheets) or `{"texelScale": N, "frames": [...]}`.
/// Decoders pick the shape from the first non-whitespace byte so a malformed file reports its
/// real decode error instead of a misleading "expected dictionary".
public enum SheetJSONShape {
    public static func isBareArray(_ data: Data) -> Bool {
        for byte in data {
            switch byte {
            case 0x20, 0x09, 0x0A, 0x0D: continue
            default: return byte == UInt8(ascii: "[")
            }
        }
        return false
    }
}
