# Project Notes

## Touch interaction

The table body now supports touch scrolling: swipe vertically to scroll rows
and swipe horizontally to scroll the area where the gesture begins. The
unpinned area and an overflowed left-pinned area use their respective scroll
controllers.

`onRowTap` and `onRowDoubleTap` now identify rows from the tap location, so
they work on touch devices without requiring mouse hover. No API changes are
required.

## Custom column header content

`DaviColumn.headerWidget` lets a column use a custom widget for its main
header content. It replaces the text normally created from `name`; the
existing leading widget, sorting controls, resizing, padding, and alignment
continue to work as before.

```dart
DaviColumn<MyRow>(
  name: 'Status', // Used when headerWidget is omitted.
  headerWidget: const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.info_outline, size: 16),
      SizedBox(width: 4),
      Text('Status'),
    ],
  ),
)
```

## DaviComparator API change

`DaviComparator<DATA>` is now a class instead of a function typedef. It
provides reusable comparators for boolean and comparable row properties, and
the default column comparator now lives inside the class.

### Migration

Before:

```dart
DaviColumn<MyRow>(
  dataComparator: (cellValueA, cellValueB, rowA, rowB) =>
      rowA.name.compareTo(rowB.name),
)
```

After:

```dart
DaviColumn<MyRow>(
  dataComparator: DaviComparator((cellValueA, cellValueB, rowA, rowB) =>
      rowA.name.compareTo(rowB.name)),
)
```

Use the helpers when appropriate:

```dart
DaviComparator.boolean((row) => row.isEnabled)
DaviComparator.comparable((row) => row.name)
```

## Updating this file

- Add an entry for every user-visible feature, behavior change, or migration.
- State what changed, who is affected, and the smallest code example needed to migrate.
- Keep entries concise and place the newest entry at the top.
- Update or remove notes once a later change makes them obsolete.
