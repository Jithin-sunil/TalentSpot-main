import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Chat extends StatefulWidget {
  final String filmmakerId; // Renamed from familyMemberId to filmmakerId
  final String userId; // Renamed from caretakerId to userId

  const Chat({super.key, required this.filmmakerId, required this.userId});

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  final SupabaseClient supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  bool isLoading = true;

  // Define colors statically to match your design
  static const Color primaryColor = Color(0xFF4361EE); // Blue
  static const Color secondaryColor = Color(0xFF64748B); // Gray
  static const Color accentColor = Colors.white; // White
  static const Color backgroundColor = Color(0xFFF8F9FA); // Light Gray

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    await fetchMessages();
    listenForMessages();
  }

  Future<void> fetchMessages() async {
    try {
      final response = await supabase
          .from('tbl_chat')
          .select()
          .match({
            'chat_fromcid': widget.userId,
            'chat_fromfid': widget.filmmakerId,
          })
          .or(
            'chat_fromfid.eq.${widget.filmmakerId},chat_tocid.eq.${widget.userId}',
          )
          .order('datetime', ascending: true);

      if (mounted) {
        setState(() {
          messages =
              response.map((msg) => Map<String, dynamic>.from(msg)).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        debugPrint('Error fetching messages: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load messages: $e')));
      }
    }
  }

  void listenForMessages() {
    supabase
        .from('tbl_chat')
        .stream(primaryKey: ['chat_id'])
        .order('datetime', ascending: true)
        .listen((snapshot) {
          if (mounted) {
            setState(() {
              final filteredMessages =
                  snapshot.where((message) {
                    return (message['chat_fromcid'] == widget.userId &&
                            message['chat_tofid'] == widget.filmmakerId) ||
                        (message['chat_fromfid'] == widget.filmmakerId &&
                            message['chat_tocid'] == widget.userId);
                  }).toList();

              for (var message in filteredMessages) {
                if (!messages.any(
                  (msg) => msg['chat_id'] == message['chat_id'],
                )) {
                  messages.add(Map<String, dynamic>.from(message));
                }
              }
            });
          }
        })
        .onError((error) {
          debugPrint('Stream error: $error');
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Stream error: $error')));
          }
        });
  }

  Future<void> sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    try {
      await supabase.from('tbl_chat').insert({
        'chat_fromcid': widget.userId, // Filmmaker sends message
        'chat_fromfid': null,
        'chat_tofid': widget.filmmakerId, // To user (caretaker)
        'chat_tocid': null,
        'chat_content': messageText,
        'datetime': DateTime.now().toIso8601String(),
      });
      _messageController.clear();
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Chat',
          style: GoogleFonts.poppins(
            fontSize: MediaQuery.of(context).size.width < 600 ? 18 : 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D3748),
          ),
        ),
        backgroundColor: accentColor,
        elevation: 2,
        shadowColor: const Color(0x0D000000).withOpacity(0.05),
      ),
      body: Column(
        children: [
          Expanded(
            child:
                isLoading
                    ? Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    )
                    : messages.isEmpty
                    ? Center(
                      child: Text(
                        'No messages yet',
                        style: GoogleFonts.poppins(
                          fontSize:
                              MediaQuery.of(context).size.width < 600 ? 14 : 16,
                          color: secondaryColor,
                        ),
                      ),
                    )
                    : ListView.builder(
                      reverse:
                          true, // Reverse order for latest messages at bottom
                      itemCount: messages.length,
                      padding: EdgeInsets.all(
                        MediaQuery.of(context).size.width * 0.04,
                      ),
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe =
                            message['chat_fromcid'] == widget.userId;

                        return Align(
                          alignment:
                              isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                          child: Container(
                            margin: EdgeInsets.symmetric(
                              vertical: 5,
                              horizontal: 10,
                            ),
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color:
                                  isMe
                                      ? primaryColor
                                      : secondaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              message['chat_content'] ?? '',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color:
                                    isMe
                                        ? accentColor
                                        : const Color(0xFF2D3748),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: secondaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: "Type a message...",
                        hintStyle: GoogleFonts.poppins(color: secondaryColor),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: primaryColor),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
