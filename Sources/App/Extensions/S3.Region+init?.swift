import SotoS3

extension SotoS3.Region {
	init?(rawValue: String?) {
		if let rawValue = rawValue {
			self.init(rawValue: rawValue)
		} else {
			return nil
		}
	}
}