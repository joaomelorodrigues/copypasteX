# copypasteX

A clean, lightweight clipboard manager for developers. copypasteX is a from-scratch Swift rewrite
of [Flycut](https://github.com/TermiT/Flycut), built for current macOS.

Copy text, images or files as usual. Press **⇧⌘V** to open your clipboard history, pick a
clipping and it's pasted.

![The copypasteX bezel on macOS: clipboard history on the left, a preview of the selected clipping on the right, and the search field at the top](docs/screenshot.png)

## Changes from Flycut

| | Flycut | copypasteX |
|---|---|---|
| Language | Objective-C (manual retain/release), ~13k lines plus vendored libraries | Swift 6 with strict concurrency, ~3k lines, no third-party dependencies |
| Content | Text only | Text, images, and copied files (videos, photos, documents) with Quick Look previews |
| macOS | 10.x era APIs (`LoginItemsAE`, `UKPrefsPanel`, ShortcutRecorder…) | macOS 14+, Liquid Glass on macOS 26+, `SMAppService`, SwiftUI settings |
| Clipboard privacy (macOS 15.4+) | Not handled | Detects "Paste from Other Apps" status and walks you through it |
| Bezel | One clipping at a time | List and full preview side by side, type to search instantly, source app icons |
| Passwords | Skips 1Password and concealed types | Skips every [nspasteboard.org](http://nspasteboard.org) private type, plus a configurable list of ignored apps |
| Storage | `NSUserDefaults` | JSON in Application Support, written atomically off the main thread, readable only by you (0600) |
| Binary | Intel/Universal | Universal (Apple silicon + Intel), hardened runtime |

Classic Flycut habits still work: the same shortcut, the same bezel keys, a non-sticky mode
(let go of the keys to paste), favorites, and Option-click on the menu bar icon to pause tracking.
You can import your existing Flycut history and favorites.

## Build and install

Requirements: Xcode 26 or later. The app runs on macOS 14 Sonoma and later.

```sh
xcodebuild -project copypasteX.xcodeproj -scheme copypasteX -configuration Release \
  -derivedDataPath build/DerivedData build
cp -R build/DerivedData/Build/Products/Release/copypasteX.app /Applications/
open /Applications/copypasteX.app
```

Or open `copypasteX.xcodeproj` and press ⌘R. To run the tests, choose the **CopypasteCore** scheme and
press ⌘U, or run `swift test` in `Packages/CopypasteCore`.

The project is signed "to run locally" (ad hoc), which gives every build a new identity, so macOS
forgets the Accessibility permission after each rebuild. To avoid that, sign with your Apple
Development certificate, either by setting your team in *Signing & Capabilities* or on the command line:

```sh
xcodebuild … CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=<TEAMID> \
  CODE_SIGN_IDENTITY="Apple Development: <Your Name> (<ID>)" build
```

To share the app with others, sign it with a Developer ID certificate and notarize it. The bundle identifier is `com.copypastex.copypasteX`; you can
change it in the target's build settings.

### Switching from Flycut

1. In copypasteX, open **Settings ▸ History ▸ Import from Flycut…** to bring over your history and favorites.
2. Quit Flycut and remove it from your login items. Both apps want ⇧⌘V, and if both run, macOS
   triggers both on the same keypress.

Updating from FlycutX, this project's earlier name? Your history and settings move over
automatically the first time copypasteX opens. Permissions have to be granted again, because
macOS ties them to the app's identity.

## Permissions

copypasteX opens its Permissions tab on first launch. It needs two permissions:

- **Accessibility**: lets copypasteX press ⌘V for you. Without it, picking a clipping only copies it.
  *Note:* with ad-hoc signing (the default), each build has a new signature. After rebuilding,
  remove copypasteX from *Privacy & Security ▸ Accessibility* and add it again, or sign with your
  development certificate as described above.
- **Paste from Other Apps** (macOS 15.4 and later): macOS now asks before apps read the clipboard in
  the background. Set copypasteX to **Allow** in *Privacy & Security ▸ Paste from Other Apps*, then
  restart copypasteX.

## Using the bezel

Press the shortcut (⇧⌘V by default). With **Sticky bezel** on (the default), the bezel stays open
until you choose. With it off, hold the modifiers, tap V to step through the list, and let go to
paste, like classic Flycut.

Just start typing to search. The search field has focus as soon as the bezel opens, and accents
and input methods work as in any text field.

| Key | Action |
|---|---|
| ↓ / ↑ | Next / previous clipping (or press the shortcut again) |
| ⌘↓ / ⌘↑, Home / End, Page Up / Page Down | Last / first, ±10 |
| ↩ | Paste the clipping (or copy it, if *Paste after choosing* is off) |
| ⌘1 – ⌘9, ⌘0 | Paste clipping 1–10 straight away |
| ⌘C or keypad Enter | Copy without pasting |
| ⌘D | Move to favorites (or back to history) |
| ⌘⌫ | Delete the clipping |
| ⇥ | Switch between history and favorites |
| ⌘S | Save the clipping to the Desktop (text as `.txt`, images and videos in their own format) |
| ⌘, | Settings |
| esc | Clear the search, or close |

You can also click a row to select it and double-click to paste.

Classic Flycut used single letters (`s`, `f`, `F`, digits) as commands. Those keys now type into the
search, and the commands moved to ⌘ shortcuts.

## Images, videos and files

- **Images** copied to the clipboard, such as screenshots (⌃⇧⌘4), "Copy Image" in a browser, or
  pictures from Preview and Photos, are kept with their size and format. They paste back as images.
- **Files** copied in Finder, including videos, photos and documents, are kept as references.
  Pasting puts the files themselves back, so they land in Finder, Mail or a chat app like any copied file.
- The preview pane shows a Quick Look thumbnail: the picture, a frame of the video, or the first
  page of a document.
- Search finds them by file name and by kind: type `video`, `image` or `pdf`.
- When something holds both text and a picture (Excel cells, Keynote shapes), the text is kept.
  The exception is a browser's "Copy Image", where the text is just the image's web address, so the
  image is kept.
- Both kinds can be turned off in **Settings ▸ History ▸ Images and Files**.

## Menu bar

The menu lists your most recent clippings (click to paste) and your favorites, and has Search,
Pause, Merge All, and Clear History. Option-click the icon to pause or resume tracking quickly, for
example while handling passwords from an app that doesn't mark them as concealed.

## Privacy

- Nothing leaves your Mac. There's no network code.
- Content marked concealed or transient (password managers, `org.nspasteboard.*` types) is never
  read. copypasteX checks the pasteboard's *types* before it reads any content.
- Apps on the ignored list (Keychain Access, Passwords, 1Password, Bitwarden, KeePassXC by default)
  are never recorded.
- History is stored at `~/Library/Application Support/copypasteX/history.json` with 0600 permissions.
  Image data goes in the `Media` folder next to it, which only you can read, and is deleted when its
  clipping is. Copied files aren't duplicated; only their location is saved.
  Turn off *Keep history after quitting* to keep history in memory only. Favorites are always saved.

## Why it's light

- **Polling that costs almost nothing.** macOS has no pasteboard-change notification, so every
  clipboard manager polls. copypasteX checks only `changeCount` twice a second, with a timer tolerance
  that lets macOS batch the wake-ups with other work. Content is read only after a change.
- **Debounced, off-main-thread saves.** A burst of copies becomes one atomic write about a second later.
- **Nothing runs while hidden.** The menu is built when you open it, the bezel's views are created on
  first use and reused, and the Settings window is released when closed.
- **Bounded work.** Text clippings over 2 MB and images over 50 MB are skipped, previews render the
  first 5,000 characters, and titles read only the start of each clipping.
- **Media done cheaply.** Identical images are stored once, compressed formats are kept instead of
  the TIFF copies apps add, a TIFF version is only produced when an app asks for one, and
  thumbnails are made only for the clipping you're looking at.

At idle, the Release build measured a 19 MB memory footprint and 0% CPU on macOS 27.

## Project layout

```
copypasteX.xcodeproj      Xcode project (folders are synchronized, so new files are picked up automatically)
copypasteX/
  App/                    AppDelegate (wiring), Preferences, ClipboardStore
  Clipboard/              PasteboardMonitor (capture), Paster (copy + ⌘V)
  HotKey/                 Carbon global hotkey, key combos, keyboard-layout mapping
  Bezel/                  Non-activating panel, controller (keymap), SwiftUI view
  MenuBar/                Status item and menu
  Settings/               SwiftUI settings and shortcut recorder
  Support/                Permissions, login item, Flycut import, display helpers, export, migration
  AppIcon.icon            Icon Composer icon (Liquid Glass; legacy icons are generated)
Packages/CopypasteCore/   Platform-independent logic with tests: Clipping, ClipList, CapturePolicy,
                          MediaLibrary, ListCursor, HistoryFile, Flycut importer
```

## License

MIT. copypasteX is new code, inspired by Flycut (Gennadiy Potapov and contributors), which is based
on Jumpcut (Steve Cook).
