import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

/// Nexora app bar
class NexoraAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;
  final Widget? leading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double elevation;
  final bool centerTitle;
  final double toolbarHeight;
  final PreferredSizeWidget? bottom;

  const NexoraAppBar({
    Key? key,
    this.title,
    this.showBackButton = true,
    this.onBackPressed,
    this.actions,
    this.leading,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation = 0,
    this.centerTitle = false,
    this.toolbarHeight = kToolbarHeight,
    this.bottom,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title != null ? Text(title!) : null,
      leading: leading ??
          (showBackButton
              ? IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
          )
              : null),
      actions: actions,
      backgroundColor: backgroundColor ?? Color(NexoraColors.surface),
      foregroundColor: foregroundColor ?? Color(NexoraColors.text),
      elevation: elevation,
      centerTitle: centerTitle,
      toolbarHeight: toolbarHeight,
      bottom: bottom,
      scrolledUnderElevation: 0,
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(toolbarHeight + (bottom?.preferredSize.height ?? 0.0));
}

/// Nexora card widget
class NexoraCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderRadius;
  final VoidCallback? onTap;
  final double elevation;
  final BoxShadow? shadow;

  const NexoraCard({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.onTap,
    this.elevation = 0,
    this.shadow,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cardWidget = Container(
      padding: padding ?? EdgeInsets.all(NexoraSpacing.lg),
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? Color(NexoraColors.surface),
        borderRadius: BorderRadius.circular(borderRadius ?? NexoraSpacing.radiusLG),
        border: Border.all(
          color: borderColor ?? Color(NexoraColors.border),
        ),
        boxShadow: shadow != null
            ? [shadow!]
            : (elevation > 0
            ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: elevation,
            offset: Offset(0, elevation / 2),
          ),
        ]
            : null),
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: cardWidget,
      );
    }

    return cardWidget;
  }
}

/// Nexora avatar widget
class NexoraAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? initials;
  final double size;
  final Color? backgroundColor;
  final Color? textColor;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const NexoraAvatar({
    Key? key,
    this.imageUrl,
    this.initials,
    this.size = 48,
    this.backgroundColor,
    this.textColor,
    this.onTap,
    this.semanticLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? Color(NexoraColors.primary),
        image: imageUrl != null
            ? DecorationImage(
          image: NetworkImage(imageUrl!),
          fit: BoxFit.cover,
        )
            : null,
      ),
      child: imageUrl == null
          ? Center(
        child: Text(
          initials ?? '?',
          style: TextStyle(
            color: textColor ?? Color(NexoraColors.surface),
            fontWeight: FontWeight.bold,
            fontSize: size / 2.5,
          ),
        ),
      )
          : null,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatar,
      );
    }

    return avatar;
  }
}

/// Nexora loading indicator
class NexoraLoadingIndicator extends StatelessWidget {
  final double size;
  final Color? color;

  const NexoraLoadingIndicator({
    Key? key,
    this.size = 40,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? Color(NexoraColors.primary),
        ),
        strokeWidth: 3,
      ),
    );
  }
}

/// Nexora error view
class NexoraErrorView extends StatelessWidget {
  final String title;
  final String message;
  final IconData? icon;
  final VoidCallback? onRetry;
  final String? retryButtonLabel;

  const NexoraErrorView({
    Key? key,
    required this.title,
    required this.message,
    this.icon,
    this.onRetry,
    this.retryButtonLabel = 'Retry',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(NexoraSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? Icons.error_outline,
              size: 64,
              color: Color(NexoraColors.error),
            ),
            SizedBox(height: NexoraSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(NexoraColors.text),
              ),
            ),
            SizedBox(height: NexoraSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(NexoraColors.textSecondary),
              ),
            ),
            if (onRetry != null) ...[
              SizedBox(height: NexoraSpacing.xl),
              ElevatedButton(
                onPressed: onRetry,
                child: Text(retryButtonLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Nexora empty state view
class NexoraEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final VoidCallback? onActionPressed;
  final String? actionLabel;

  const NexoraEmptyState({
    Key? key,
    required this.icon,
    required this.title,
    this.description,
    this.onActionPressed,
    this.actionLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(NexoraSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Color(NexoraColors.textMuted),
            ),
            SizedBox(height: NexoraSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(NexoraColors.text),
              ),
            ),
            if (description != null) ...[
              SizedBox(height: NexoraSpacing.md),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(NexoraColors.textSecondary),
                ),
              ),
            ],
            if (onActionPressed != null && actionLabel != null) ...[
              SizedBox(height: NexoraSpacing.xl),
              ElevatedButton(
                onPressed: onActionPressed,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
