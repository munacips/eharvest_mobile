import 'package:flutter/widgets.dart';

class ResponsiveBreakpoints {
  static const double tablet = 600;
  static const double desktop = 900;
  static const double wideDesktop = 1200;
  static const double maxContentWidth = 1120;
  static const double maxFormWidth = 960;
  static const double maxListWidth = 980;
  static const double maxLoginWidth = 520;

  const ResponsiveBreakpoints._();

  static bool isDesktopWidth(double width) => width >= desktop;

  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= desktop;
  }

  static int productGridColumns(double width) {
    if (width >= 1400) {
      return 5;
    }
    if (width >= wideDesktop) {
      return 4;
    }
    if (width >= desktop) {
      return 3;
    }
    return 2;
  }

  static double productGridAspectRatio(double width) {
    return isDesktopWidth(width) ? 0.68 : 0.54;
  }
}

class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = ResponsiveBreakpoints.maxContentWidth,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!ResponsiveBreakpoints.isDesktopWidth(constraints.maxWidth)) {
          return child;
        }

        return Align(
          alignment: alignment,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        );
      },
    );
  }
}
