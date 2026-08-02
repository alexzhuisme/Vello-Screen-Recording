import OSLog

public enum Log {
    private static let subsystem = "app.vello.Vello"

    public static let app = Logger(subsystem: subsystem, category: "app")
    public static let capture = Logger(subsystem: subsystem, category: "capture")
    public static let export = Logger(subsystem: subsystem, category: "export")
    public static let settings = Logger(subsystem: subsystem, category: "settings")
}
