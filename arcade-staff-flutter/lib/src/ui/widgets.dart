import 'package:flutter/material.dart';

const clubLogoAsset = 'assets/images/insights_club_logo.png';

class AppBackdrop extends StatelessWidget {
  const AppBackdrop({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0B0D12),
                  Color(0xFF0F121A),
                  Color(0xFF0A0C11)
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -120,
          left: -100,
          child: IgnorePointer(
            child: Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x22FF7A1A),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: const Color(0xFF97A1B2))),
        ]
      ],
    );
  }
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class ClubAppBarTitle extends StatelessWidget {
  const ClubAppBarTitle({
    super.key,
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 360;
    final logoSize = isCompact ? 22.0 : 26.0;
    final gap = isCompact ? 6.0 : 8.0;
    final maxTitleWidth = width * (isCompact ? 0.52 : 0.62);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.asset(
            clubLogoAsset,
            width: logoSize,
            height: logoSize,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.shield_outlined, size: logoSize - 4),
          ),
        ),
        SizedBox(width: gap),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxTitleWidth),
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}
