import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'news_feed_screen.dart'; // Importamos la nueva pantalla de noticias

class CommunityForumScreen extends StatefulWidget {
  const CommunityForumScreen({super.key});

  @override
  State<CommunityForumScreen> createState() => _CommunityForumScreenState();
}

class _CommunityForumScreenState extends State<CommunityForumScreen> {
  bool _isLoading = true;
  List<dynamic> _posts = [];
  String _selectedCategory = 'Todos';

  // 'Noticia' eliminado de las categorías del foro
  final List<String> _categories = [
    'Todos',
    'Revisión de Serie',
    'Consejo Técnico',
    'General'
  ];

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('es', timeago.EsMessages());
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    setState(() => _isLoading = true);
    try {
      var query = Supabase.instance.client
          .from('forum_posts')
          .select('id, title, content, category, created_at, profiles(full_name)');

      if (_selectedCategory != 'Todos') {
        query = query.eq('category', _selectedCategory);
      }

      final response = await query.order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _posts = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar posts: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCreatePostModal() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String category = 'General';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF2C2C2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nueva Publicación', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: category,
                    dropdownColor: const Color(0xFF1E1E1E),
                    style: const TextStyle(color: Colors.white),
                    items: _categories.where((c) => c != 'Todos').map((c) {
                      return DropdownMenuItem(value: c, child: Text(c));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => category = val);
                    },
                    decoration: InputDecoration(
                      labelText: 'Categoría',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Título',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: contentController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Contenido / Pregunta',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: () async {
                        if (titleController.text.isEmpty || contentController.text.isEmpty) return;
                        
                        final userId = Supabase.instance.client.auth.currentUser?.id;
                        if (userId == null) return;

                        await Supabase.instance.client.from('forum_posts').insert({
                          'user_id': userId,
                          'title': titleController.text,
                          'content': contentController.text,
                          'category': category,
                        });

                        if (mounted) {
                          Navigator.pop(context);
                          _fetchPosts();
                        }
                      },
                      child: const Text('Publicar', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Envolvemos el Scaffold en DefaultTabController
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF333333),
        appBar: AppBar(
          backgroundColor: const Color(0xFF180A0A),
          title: const Text('Comunidad', style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
          // Agregamos las pestañas
          bottom: const TabBar(
            indicatorColor: Colors.orangeAccent,
            labelColor: Colors.orangeAccent,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'Foro'),
              Tab(text: 'Noticias'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.orangeAccent,
          onPressed: _showCreatePostModal,
          child: const Icon(Icons.add, color: Colors.black),
        ),
        // TabBarView muestra una pantalla u otra según la pestaña seleccionada
        body: TabBarView(
          children: [
            // Pestaña 1: El Foro actual
            Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: _categories.map((category) {
                      final isSelected = _selectedCategory == category;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: isSelected,
                          selectedColor: Colors.orangeAccent,
                          backgroundColor: const Color(0xFF1E1E1E),
                          labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedCategory = category);
                              _fetchPosts();
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.orangeAccent))
                      : _posts.isEmpty
                          ? const Center(child: Text('Aún no hay publicaciones.', style: TextStyle(color: Colors.white54)))
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _posts.length,
                              itemBuilder: (context, index) {
                                final post = _posts[index];
                                final author = post['profiles']?['full_name'] ?? 'Usuario Anónimo';
                                final date = DateTime.parse(post['created_at']);
                                final timeAgoStr = timeago.format(date, locale: 'es');

                                return Card(
                                  color: const Color(0xFF2C2C2C),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              post['category'],
                                              style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                            Text(
                                              timeAgoStr,
                                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          post['title'],
                                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          post['content'],
                                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            const Icon(Icons.person, size: 14, color: Colors.white54),
                                            const SizedBox(width: 4),
                                            Text(author, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
            
            // Pestaña 2: Las noticias automatizadas
            const NewsFeedScreen(),
          ],
        ),
      ),
    );
  }
}