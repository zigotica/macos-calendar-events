# MacOS Calendar Events

This is a small Swift script that compiles into a binary to display upcoming events from the macOS Calendar app. It's designed for integration with [SketchyBar](https://github.com/knollmeyer/sketchybar) but can be used anywhere.

Unlike tools like iCalBuddy, this script avoids common macOS TCC (Transparency, Consent, and Control) permission issues by using the native EventKit framework.

## 🛠️ Compilation

You only need to compile the Swift script once:

```bash
swiftc CalendarEvents.swift -o ~/.config/sketchybar/calendar_events
```

You can change the output path or binary name as needed.

## 🔖 Selecting Calendars

Create a `calendars.txt` file in the same directory as the compiled script, listing the names of the calendars you want to include — one per line:


```text
calendar A
calendar B
```

Only events from calendars listed in this file will be shown. If this file is not present, all calendars will be used.

## Usage of compiled binary

You can pass the number of days to fetch as a command-line argument when running the compiled binary.
For example, to fetch events for today and the next 2 days (3 days total):

```bash
~/.config/sketchybar/calendar_events 3
```

If no argument is provided, the default is 1 (only today).

## Output

The binary prints upcoming events to stdout in this format:

```text
09:00–10:00 | Daily Standup
14:30–15:00 | Design Review
```

Use the output as input for your SketchyBar plugin or other automation scripts. Enjoy a TCC-free, native way to display calendar events on your Mac!

## 🧪 Debugging

To list all available calendar names (to help you build calendars.txt), uncomment the debug print section in the script:

```swift
for cal in store.calendars(for: .event) {
    print("- \(cal.title)")
}
```

Then recompile and run the binary to see the output.
