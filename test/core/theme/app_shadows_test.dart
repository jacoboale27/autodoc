import 'package:flutter_test/flutter_test.dart';
import 'package:autodoc/core/theme/app_shadows.dart';

void main() {
  test('lightHover cae entre lightMd y lightLg en intensidad', () {
    final hover = AppShadows.lightHover.first;
    final md = AppShadows.lightMd.first;
    final lg = AppShadows.lightLg.first;

    expect(hover.blurRadius, greaterThan(md.blurRadius));
    expect(hover.blurRadius, lessThan(lg.blurRadius));
    expect(hover.offset.dy, greaterThan(md.offset.dy));
    expect(hover.offset.dy, lessThan(lg.offset.dy));
    expect(hover.color.a, greaterThan(md.color.a));
    expect(hover.color.a, lessThan(lg.color.a));
  });

  test('darkHover cae entre darkMd y darkLg en intensidad', () {
    final hover = AppShadows.darkHover.first;
    final md = AppShadows.darkMd.first;
    final lg = AppShadows.darkLg.first;

    expect(hover.blurRadius, greaterThan(md.blurRadius));
    expect(hover.blurRadius, lessThan(lg.blurRadius));
    expect(hover.offset.dy, greaterThan(md.offset.dy));
    expect(hover.offset.dy, lessThan(lg.offset.dy));
  });
}
