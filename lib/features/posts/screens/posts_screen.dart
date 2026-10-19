import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/security/roles_and_permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/buttons/ajra_button.dart';
import '../../../shared/widgets/forms/ajra_text_field.dart';
import '../../../shared/widgets/states/empty_state_view.dart';
import '../../../shared/widgets/states/loading_state_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/post_item.dart';

final postsStreamProvider = StreamProvider<List<PostItem>>((ref) {
  return FirebaseFirestore.instance
      .collection(AppConstants.colPosts)
      .orderBy('publishedAt', descending: true)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => PostItem.fromJson(doc.data(), doc.id)).toList();
  });
});

class PostsScreen extends ConsumerStatefulWidget {
  const PostsScreen({super.key});

  @override
  ConsumerState<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends ConsumerState<PostsScreen> {
  Future<void> _openCreatePostDialog() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final titleController = TextEditingController();
    final contentController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Publier une actualité'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AjraTextField(
              controller: titleController,
              label: 'Titre de l\'annonce *',
              hint: 'ex: Rapport moral du président',
            ),
            const SizedBox(height: 14),
            AjraTextField(
              controller: contentController,
              label: 'Contenu *',
              hint: 'Rédigez votre annonce officielle...',
              maxLines: 5,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Publier'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      if (titleController.text.trim().isEmpty || contentController.text.trim().isEmpty) return;

      final post = PostItem(
        id: const Uuid().v4(),
        title: titleController.text.trim(),
        content: contentController.text.trim(),
        authorUserId: user.uid,
        authorName: user.displayName,
        publishedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection(AppConstants.colPosts)
          .doc(post.id)
          .set(post.toJson());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Actualité publiée avec succès !'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final canPublish = user != null && (user.isAdmin || user.canPublishPosts);
    final postsAsync = ref.watch(postsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Actualités AJRA'),
        actions: [
          if (canPublish)
            IconButton(
              icon: const Icon(Icons.post_add_rounded),
              tooltip: 'Créer une actualité',
              onPressed: _openCreatePostDialog,
            ),
        ],
      ),
      body: postsAsync.when(
        data: (posts) {
          if (posts.isEmpty) {
            return const EmptyStateView(
              icon: Icons.newspaper_outlined,
              title: 'Aucune publication pour l\'instant',
              message: 'Les annonces officielles de l\'association s\'afficheront ici.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final post = posts[index];
              final dateStr =
                  DateFormat('d MMMM yyyy à HH:mm', 'fr_FR').format(post.publishedAt);

              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
                          child: const Icon(Icons.campaign, size: 18, color: AppColors.primary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.authorName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                dateStr,
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.textSecondaryLight),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      post.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      post.content,
                      style: const TextStyle(fontSize: 13.5, height: 1.45),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const LoadingStateView(message: 'Chargement des actualités...'),
        error: (e, _) => Center(child: Text('Erreur : ${e.toString()}')),
      ),
    );
  }
}
