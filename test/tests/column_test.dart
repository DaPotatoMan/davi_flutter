import 'package:davi/davi.dart';
import 'package:davi/src/column.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DaviComparator', () {
    test('default comparator sorts supported cell values', () {
      final comparator = DaviColumn<int>().dataComparator;

      expect(comparator(null, null, 0, 0), 0);
      expect(comparator(null, 1, 0, 1), lessThan(0));
      expect(comparator(1, null, 0, 1), greaterThan(0));
      expect(comparator('a', 'b', 0, 1), lessThan(0));
      expect(comparator(1, 2, 0, 1), lessThan(0));
      expect(comparator(1.0, 2.0, 0, 1), lessThan(0));
      expect(comparator(1, '1', 0, 1), 0);
    });

    test('boolean and comparable factories sort rows', () {
      final booleanComparator = DaviComparator.boolean((bool value) => value);
      final comparableComparator = DaviComparator.comparable((String value) => value);

      expect(booleanComparator(null, null, false, true), lessThan(0));
      expect(comparableComparator(null, null, 'a', 'b'), lessThan(0));
    });
  });

  group('DaviColumn', () {
    test('setting sort', () {
      DaviColumn column = DaviColumn(id: 'id', sortable: true);
      DaviColumnHelper.setSort(
          column: column, direction: DaviSortDirection.ascending, priority: 2);
      expect(column.sortPriority, 2);

      column = DaviColumn(id: 'id', sortable: false);
      expect(
          () => DaviColumnHelper.setSort(
              column: column,
              direction: DaviSortDirection.ascending,
              priority: 1),
          throwsA(const TypeMatcher<ArgumentError>()));

      column = DaviColumn(id: 1);
      expect(
          DaviColumnHelper.setSortPriority(column: column, priority: 1), false);
    });
  });
}
