import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 24,
  });

  final String? name;
  final String? imageUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initials = name?.trim().isNotEmpty == true
        ? name!.trim().substring(0, 1).toUpperCase()
        : '?';
    final colors = Theme.of(context).colorScheme;

    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.primaryContainer,
      child: ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: imageUrl == null || imageUrl!.isEmpty
              ? Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: colors.onPrimaryContainer,
                      fontSize: radius,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: colors.onPrimaryContainer,
                        fontSize: radius,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
