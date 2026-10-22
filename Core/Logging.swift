import OSLog

/// Central place for `os.Logger` instances; one category per subsystem of the app.
public enum Log {
    public static let subsystem = "com.frdzhv.NextCall"

    public static let app = Logger(subsystem: subsystem, category: "app")
    public static let calendar = Logger(subsystem: subsystem, category: "calendar")
    public static let links = Logger(subsystem: subsystem, category: "links")
    public static let scheduling = Logger(subsystem: subsystem, category: "scheduling")
    public static let launching = Logger(subsystem: subsystem, category: "launching")
}
