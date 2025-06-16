import Foundation
import EventKit

#if os(macOS)
import Darwin

func getExecutablePath() -> URL? {
    var bufsize = UInt32(PATH_MAX)
    let buf = UnsafeMutablePointer<Int8>.allocate(capacity: Int(bufsize))
    defer { buf.deallocate() }
    let result = _NSGetExecutablePath(buf, &bufsize)
    if result != 0 {
        // Buffer was too small or error
        return nil
    }
    let path = String(cString: buf)
    // Resolve symlinks, .., etc
    return URL(fileURLWithPath: path).standardized.deletingLastPathComponent()
}
#else
func getExecutablePath() -> URL? {
    // Fallback for other OSes if needed
    return nil
}
#endif

let store = EKEventStore()
let semaphore = DispatchSemaphore(value: 0)

// How many days ahead to look (up to the end of that day, 1 being today)
// Parse command-line argument for number of days to fetch (default is 1)
let defaultDaysToFetch = 1
let daysToFetch: Int = {
    if CommandLine.arguments.count > 1, let arg = Int(CommandLine.arguments[1]), arg > 0 {
        return arg
    }
    return defaultDaysToFetch
}()

func loadAllowedCalendars(from allCalendars: [EKCalendar]) -> [EKCalendar] {
    guard let binaryDir = getExecutablePath() else {
        print("Could not resolve binary path. Using all calendars.")
        return allCalendars
    }

    let fileURL = binaryDir.appendingPathComponent("calendars.txt")
    print("Looking for calendars.txt at: \(fileURL.path)")

    do {
        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = contents
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let allowed = Set(lines)
        let selected = allCalendars.filter { allowed.contains($0.title) }

        if selected.isEmpty {
            print("No matching calendars found in calendars.txt. Using all calendars instead.")
            return allCalendars
        }

        return selected
    } catch {
        print("No calendars.txt found or failed to read it. Using all calendars.")
        return allCalendars
    }
}

func fetchEvents() {
    // Fetch all event calendars
    let allCalendars = store.calendars(for: .event)

    // Filter calendars by name
    let selectedCalendars = loadAllowedCalendars(from: allCalendars)

    print("Selected calendars:")
    for cal in selectedCalendars {
        print("- \(cal.title)")
    }
    print("-----")

    if selectedCalendars.isEmpty {
        print("No matching calendars found.")
        return
    }

    let now = Date()
    var calendar = Calendar.current
    calendar.locale = Locale(identifier: "en_US_POSIX")

    if let targetDay = calendar.date(byAdding: .day, value: daysToFetch - 1, to: now),
        let endOfTargetDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: targetDay) {

        let predicate = store.predicateForEvents(withStart: now, end: endOfTargetDay, calendars: selectedCalendars)
        let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        for event in events where event.endDate > now {
            let startTime = timeFormatter.string(from: event.startDate)
            let endTime = timeFormatter.string(from: event.endDate)
            let dateString = dateFormatter.string(from: event.startDate)
            let title = (event.title ?? "(No Title)")
                .replacingOccurrences(of: "\u{00A0}", with: " ")    // Replace non-breaking space
                .replacingOccurrences(of: "\u{2013}", with: "-")    // Replace en dash

            print("\(dateString) \(startTime)-\(endTime) | \(title)")
        }
    } else {
        print("Failed to calculate end date")
    }
}

if #available(macOS 14.0, *) {
    store.requestFullAccessToEvents { granted, error in
        if granted {
            fetchEvents()
        } else {
            print("Access denied or error: \(error?.localizedDescription ?? "unknown error")")
        }
        semaphore.signal()
    }
} else {
    store.requestAccess(to: .event) { granted, error in
        if granted {
            fetchEvents()
        } else {
            print("Access denied or error: \(error?.localizedDescription ?? "unknown error")")
        }
        semaphore.signal()
    }
}

_ = semaphore.wait(timeout: .distantFuture)

