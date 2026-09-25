package address

// Detect identifies the AddressKind of a Stellar address string.
// Supported kinds include KindG (Ed25519), KindM (Muxed/SEP-23), and KindC (Contract).
func Detect(addr string) (AddressKind, error) {
	versionByte, _, _, err := decodeStrKey(addr)
	if err != nil {
		return "", err
	}
	return kindForVersionByte(versionByte)
}
