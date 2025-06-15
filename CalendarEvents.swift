import Foundation
import EventKit

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
    let binaryPath = CommandLine.arguments.first ?? ""
    let binaryDir = URL(fileURLWithPath: binaryPath).deletingLastPathComponent()
    let fileURL = binaryDir.appendingPathComponent("calendars.txt")

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
    // Uncomment to check the names of the available calendars
    // Compile normally and execute the binary to see the output
    // print("Available calendars:")
    // for cal in store.calendars(for: .event) {
    //     print("- \(cal.title)")
    // }
    // print("-----")

    // Fetch all event calendars
    let allCalendars = store.calendars(for: .event)

    // Filter calendars by name
    let selectedCalendars = loadAllowedCalendars(from: allCalendars)

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

        for event in events where event.startDate > now {
            let startTime = timeFormatter.string(from: event.startDate)
            let endTime = timeFormatter.string(from: event.endDate)
            let title = event.title ?? "(No Title)"
            print("\(startTime)–\(endTime) | \(title)")
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

