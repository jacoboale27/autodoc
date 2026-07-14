import 'package:flutter/material.dart';
import 'package:autodoc/core/theme/app_colors.dart';
import 'package:autodoc/core/utils/responsive.dart';

class AppScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool useGradient;

  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.useGradient = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      appBar: appBar,
      body: Column(
        children: [
        // AppTopNavBar is now handled by MainScaffold globally
        // if (Responsive.isDesktop(context))
        //   const Padding(
        //     padding: EdgeInsets.only(top: 8.0),
        //     child: AppTopNavBar(),
        //   ),
        Expanded(
            child: useGradient
                ? Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colors.surface,
                          colors.surface.withValues(alpha: 0.95),
                        ],
                      ),
                    ),
                    child: body,
                  )
                : body,
          ),
        ],
      ),
      bottomNavigationBar: Responsive.isDesktop(context) ? null : bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}
