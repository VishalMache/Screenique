import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../services/auth_service.dart';
import '../../services/watchlist_service.dart';
import '../../services/movie_service.dart';

import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Color get bgColor => Theme.of(context).scaffoldBackgroundColor;
  Color get noirColor => Theme.of(context).primaryColor;
  Color get accentColor => Theme.of(context).hintColor;

  bool _isPublicProfile = true;
  bool _notificationsEnabled = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _isPublicProfile = doc.data()?['isPublic'] ?? true;
        });
      }
    }

    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      });
    }
  }

  Future<void> _savePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    }
  }

  void _clearAppCache() async {
    await MovieService.clearCache();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Cache cleared successfully.", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: noirColor,
        ),
      );
    }
  }

  Future<void> _exportArchiveAsPDF(User? user) async {
    if (user == null || _exporting) return;

    setState(() { _exporting = true; });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('movies')
          .get();

      final List<Map<String, dynamic>> records = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? 'Unknown Media',
          'status': data['status'] ?? 'watched',
          'userRating': data['userRating'] ?? 3.0,
          'isTvShow': data['isTvShow'] ?? false,
          'director': data['director'] ?? 'UNKNOWN',
          'timestamp': data['timestamp'] != null
              ? (data['timestamp'] as Timestamp).toDate().toIso8601String()
              : DateTime.now().toIso8601String(),
        };
      }).toList();

      final pdfDoc = pw.Document();

      pdfDoc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(32),
          header: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: pw.EdgeInsets.only(bottom: 20.0),
              child: pw.Text(
                'SCREENIQUE SYSTEM EXPORT - PAGE ${context.pageNumber} OF ${context.pagesCount}',
                style: pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
              ),
            );
          },
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "SCREENIQUE CINEMA DOSSIER",
                      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                    ),
                    pw.Text(
                      "EXPORT DATE: ${DateTime.now().toLocal().toString().split(' ')[0]}",
                      style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text("USER ACCOUNT: ${user.email ?? 'unknown'}", style: pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
              pw.Text("TOTAL MEDIA ENTRIES: ${records.length}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.black, width: 1.5),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
                cellStyle: pw.TextStyle(fontSize: 8),
                headerDecoration: pw.BoxDecoration(color: PdfColors.black),
                headers: ['TITLE', 'TYPE', 'DIRECTOR', 'RATING', 'RECORD DATE'],
                data: records.map((m) {
                  final dateStr = m['timestamp'].toString().split('T')[0];
                  return [
                    m['title'].toString().toUpperCase(),
                    (m['isTvShow'] as bool ? 'SERIES' : 'FILM'),
                    m['director'].toString().toUpperCase(),
                    '${m['userRating']}/5.0',
                    dateStr,
                  ];
                }).toList(),
              ),
            ];
          },
        ),
      );

      final tempDir = await getTemporaryDirectory();
      final File exportFile = File('${tempDir.path}/screenique_cinema_dossier.pdf');
      await exportFile.writeAsBytes(await pdfDoc.save());

      await Share.shareXFiles(
        [XFile(exportFile.path)],
        subject: 'Screenique Cinema Dossier Backup',
        text: 'Here is my cinema archive dossier exported from Screenique.',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("PDF export completed.", style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: noirColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Export failed: $e", style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: accentColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() { _exporting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String photoUrl = user?.photoURL ??
        'https://ui-avatars.com/api/?name=${user?.email ?? "User"}&background=111111&color=f4f4ec';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F3EB), // Soft cream background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF111111), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            const Text(
              "S E T T I N G S",
              style: TextStyle(
                letterSpacing: 4, 
                fontSize: 14, 
                fontWeight: FontWeight.w900, 
                color: Color(0xFF111111),
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "Your account, your experience",
              style: TextStyle(
                fontSize: 10, 
                color: const Color(0xFF111111).withOpacity(0.5),
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 6),
            Container(width: 30, height: 2, color: const Color(0xFFD32F2F)), // Red underline
          ],
        ),
        toolbarHeight: 80,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              // --- 1. USER PROFILE QUICK-CARD ---
              _buildUserProfileCard(user, photoUrl),
              const SizedBox(height: 32),

              // --- 2. ACCOUNT CONFIGURATION ---
              _buildSectionHeader(Icons.person, "ACCOUNT", "Manage your account details"),
              _buildSettingCard([
                _buildActionTile(
                  Icons.edit_square,
                  "Edit Display Name",
                  subtitle: user?.displayName ?? "Cinema Buff",
                  onTap: () => _showEditNameDialog(user),
                ),
                _buildActionTile(
                  Icons.alternate_email_rounded,
                  "Edit Username",
                  subtitle: "Change your @handle",
                  onTap: () => _showEditUsernameDialog(user),
                ),
                _buildActionTile(
                  Icons.description_outlined,
                  "Edit Bio",
                  subtitle: "Update your public profile bio",
                  onTap: () => _showEditBioDialog(user),
                ),
                _buildActionTile(
                  Icons.lock_outline_rounded,
                  "Change Password",
                  subtitle: "Update your password",
                  onTap: () => _sendPasswordReset(user),
                ),
                _buildActionTile(
                  Icons.logout_rounded,
                  "Sign Out",
                  subtitle: "Sign out of your account",
                  isDestructive: true,
                  onTap: () => _showSignOutDialog(),
                ),
              ]),
              const SizedBox(height: 32),

              // --- 3. PRIVACY & NOTIFICATIONS ---
              _buildSectionHeader(Icons.settings, "PRIVACY & NOTIFICATIONS", "Control your visibility and alerts"),
              _buildSettingCard([
                _buildToggleTile(
                  Icons.language_rounded,
                  "Public Profile",
                  "Let others see your profile and activity",
                  _isPublicProfile,
                  (val) async {
                    setState(() => _isPublicProfile = val);
                    await WatchlistService().toggleProfilePrivacy(val);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(val ? "Profile is now public." : "Profile is now private.", style: const TextStyle(fontWeight: FontWeight.bold)),
                          backgroundColor: const Color(0xFF111111),
                        ),
                      );
                    }
                  },
                ),
                _buildToggleTile(
                  Icons.notifications_none_rounded,
                  "Notifications",
                  "Get updates about movies, community and more",
                  _notificationsEnabled,
                  (val) {
                    setState(() => _notificationsEnabled = val);
                    _savePreference('notificationsEnabled', val);
                  },
                ),
              ]),
              const SizedBox(height: 32),

              // --- 4. DATA & ARCHIVE ---
              _buildSectionHeader(Icons.storage_rounded, "DATA & ARCHIVE", "Manage your data and recommendations"),
              _buildSettingCard([
                _buildActionTile(
                  Icons.cleaning_services_outlined,
                  "Clear Cache",
                  subtitle: "Free up temporary storage",
                  onTap: () => _clearAppCache(),
                ),
                _buildActionTile(
                  _exporting ? Icons.sync : Icons.download_rounded,
                  _exporting ? "Generating PDF..." : "Export Watched Movies",
                  subtitle: "Download your watched list as a PDF",
                  onTap: () => _exportArchiveAsPDF(user),
                ),
                _buildActionTile(
                  Icons.sync_rounded,
                  "Reset Recommendations",
                  subtitle: "Start fresh with new suggestions",
                  isDestructive: false,
                  onTap: () => _showResetTasteProfileDialog(user),
                ),
                _buildActionTile(
                  Icons.history_rounded,
                  "Reset Movie History",
                  subtitle: "Remove all your watched data",
                  isDestructive: true,
                  onTap: () => _showResetJourneyDialog(),
                ),
              ]),
              const SizedBox(height: 32),

              // --- 5. ABOUT & SUPPORT ---
              _buildSectionHeader(Icons.info_outline_rounded, "ABOUT", "App information and legal"),
              _buildSettingCard([
                _buildActionTile(
                  Icons.movie_creation_outlined,
                  "About Screenique",
                  subtitle: "Version 1.0.0 • Powered by TMDB",
                  onTap: () => _showAboutDialog(),
                ),
              ]),
              const SizedBox(height: 32),

              // --- 6. DANGER ZONE ---
              _buildSectionHeader(Icons.warning_amber_rounded, "DANGER ZONE", "Irreversible actions", isDestructive: true),
              _buildSettingCard([
                _buildActionTile(
                  Icons.delete_outline_rounded,
                  "Delete Account",
                  subtitle: "Permanently delete your account and all your data",
                  isDestructive: true,
                  onTap: () => _showDeleteAccountDialog(user),
                ),
              ], isDangerZone: true),

              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildSectionHeader(IconData icon, String title, String subtitle, {bool isDestructive = false}) {
    final color = isDestructive ? const Color(0xFFD32F2F) : const Color(0xFF111111);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, right: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: color, 
              fontWeight: FontWeight.w900, 
              letterSpacing: 2, 
              fontSize: 12,
              fontFamily: 'Inter'
            ),
          ),
          const Spacer(),
          Text(
            subtitle,
            style: TextStyle(
              color: const Color(0xFF111111).withOpacity(0.5), 
              fontSize: 10,
              fontFamily: 'Inter'
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserProfileCard(User? user, String photoUrl) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(user?.uid).get(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final username = userData?['username'] ?? 'user';
        
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFEBE7DE), // Slightly darker cream for the card
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: NetworkImage(photoUrl),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF111111),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      user?.displayName ?? "Cinema Buff",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter', 
                        fontSize: 18, 
                        fontWeight: FontWeight.bold, 
                        color: Color(0xFF111111)
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "@$username",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12, 
                        color: const Color(0xFF111111).withOpacity(0.6),
                        fontFamily: 'Inter'
                      ),
                    ),
                    Text(
                      user?.email ?? "no-email@screenique.com",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11, 
                        color: const Color(0xFF111111).withOpacity(0.4),
                        fontFamily: 'Inter'
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEAEA), // Light red background
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.stars_rounded, color: Color(0xFFD32F2F), size: 12),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              "Verified Cinema Archivist",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Color(0xFFD32F2F), 
                                fontSize: 9, 
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Inter'
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3EB),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          )
                        ]
                      ),
                      child: Row(
                        children: const [
                          Text("View Profile", style: TextStyle(color: Color(0xFF111111), fontSize: 10, fontWeight: FontWeight.bold)),
                          SizedBox(width: 2),
                          Icon(Icons.arrow_forward_ios_rounded, size: 8, color: Color(0xFF111111)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              // Faint vertical text
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFaintText("GOOD"),
                  _buildFaintText("MOVIES"),
                  _buildFaintText("BETTER"),
                  _buildFaintText("PEOPLE"),
                ],
              )
            ],
          ),
        );
      }
    );
  }

  Widget _buildFaintText(String text) {
    return Text(
      text, 
      style: TextStyle(
        color: const Color(0xFF111111).withOpacity(0.15),
        fontSize: 8,
        fontWeight: FontWeight.w900,
        letterSpacing: 1
      )
    );
  }

  Widget _buildSettingCard(List<Widget> children, {bool isDangerZone = false}) {
    return Container(
      decoration: BoxDecoration(
        color: isDangerZone ? const Color(0xFFFFEEEE) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: List.generate(children.length, (index) {
          if (index == children.length - 1) return children[index];
          return Column(
            children: [
              children[index],
              Divider(height: 1, thickness: 1, color: const Color(0xFF111111).withOpacity(0.05), indent: 56, endIndent: 20),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String title, {required String subtitle, required VoidCallback onTap, bool isDestructive = false}) {
    final color = isDestructive ? const Color(0xFFD32F2F) : const Color(0xFF111111);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: color, 
          fontWeight: FontWeight.bold, 
          fontSize: 14,
          fontFamily: 'Inter'
        ),
      ),
      subtitle: Text(
        subtitle, 
        style: TextStyle(
          color: color.withOpacity(0.5), 
          fontSize: 11,
          fontFamily: 'Inter'
        )
      ),
      trailing: Icon(Icons.arrow_forward_ios_rounded, color: color.withOpacity(0.5), size: 14),
    );
  }

  Widget _buildToggleTile(IconData icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      activeColor: Colors.white,
      activeTrackColor: const Color(0xFFD32F2F),
      inactiveThumbColor: Colors.white,
      inactiveTrackColor: Colors.grey.shade300,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: const Color(0xFF111111), size: 24),
      ),
      title: Text(
        title, 
        style: const TextStyle(
          color: Color(0xFF111111), 
          fontWeight: FontWeight.bold, 
          fontSize: 14,
          fontFamily: 'Inter'
        )
      ),
      subtitle: Text(
        subtitle, 
        style: TextStyle(
          color: const Color(0xFF111111).withOpacity(0.5), 
          fontSize: 11,
          fontFamily: 'Inter'
        )
      ),
    );
  }

  // --- DIALOGS ---

  void _sendPasswordReset(User? user) async {
    if (user?.email == null) return;
    // Check if user signed in with Google (no password to reset)
    final providers = user!.providerData.map((p) => p.providerId).toList();
    if (providers.contains('google.com') && !providers.contains('password')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("You signed in with Google. Password reset is not applicable.", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: noirColor,
        ),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Password reset email sent to ${user.email}.", style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: noirColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to send reset email.", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: accentColor),
        );
      }
    }
  }

  void _showEditNameDialog(User? user) {
    final controller = TextEditingController(text: user?.displayName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(side: BorderSide(color: noirColor, width: 2)),
        title: Text("Edit Display Name", style: TextStyle(color: noirColor, fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: noirColor),
          decoration: InputDecoration(
            hintText: "Enter your name",
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: noirColor, width: 2)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: noirColor, width: 2)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCEL", style: TextStyle(color: noirColor))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: noirColor, foregroundColor: bgColor),
            onPressed: () async {
              await WatchlistService().updateDisplayName(controller.text);
              if (mounted) setState(() {});
              if (context.mounted) Navigator.pop(context);
            },
            child: Text("SAVE", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditUsernameDialog(User? user) async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final currentUsername = doc.data()?['username'] ?? '';
    if (!mounted) return;

    final controller = TextEditingController(text: currentUsername);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(side: BorderSide(color: noirColor, width: 2)),
        title: Text("Edit Username", style: TextStyle(color: noirColor, fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: noirColor),
          decoration: InputDecoration(
            prefixText: "@",
            prefixStyle: TextStyle(color: noirColor, fontWeight: FontWeight.bold),
            hintText: "your_handle",
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: noirColor, width: 2)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: noirColor, width: 2)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCEL", style: TextStyle(color: noirColor))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: noirColor, foregroundColor: bgColor),
            onPressed: () async {
              final newUsername = controller.text.trim().toLowerCase().replaceAll(' ', '_');
              if (newUsername.isEmpty) return;
              await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'username': newUsername});
              if (context.mounted) Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Username updated to @$newUsername.", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: noirColor),
                );
              }
            },
            child: Text("SAVE", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditBioDialog(User? user) async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final currentBio = doc.data()?['bio'] ?? '';
    if (!mounted) return;

    final controller = TextEditingController(text: currentBio);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(side: BorderSide(color: noirColor, width: 2)),
        title: Text("Edit Bio", style: TextStyle(color: noirColor, fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 120,
          style: TextStyle(color: noirColor),
          decoration: InputDecoration(
            hintText: "Enter a brief bio...",
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: noirColor, width: 2)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: noirColor, width: 2)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCEL", style: TextStyle(color: noirColor))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: noirColor, foregroundColor: bgColor),
            onPressed: () async {
              await WatchlistService().updateBio(controller.text.trim());
              if (context.mounted) Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Bio updated.", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: noirColor),
                );
              }
            },
            child: Text("SAVE", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showResetTasteProfileDialog(User? user) {
    if (user == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(side: BorderSide(color: noirColor, width: 2)),
        title: Text("RESET TASTE PROFILE?", style: TextStyle(color: noirColor, fontWeight: FontWeight.bold)),
        content: Text(
          "This will clear your AI recommendation data. Screenique will re-learn your preferences as you continue watching. This cannot be undone.",
          style: TextStyle(color: noirColor, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCEL", style: TextStyle(color: noirColor))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: bgColor),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('taste_profile')
                  .doc('main')
                  .delete();
              if (context.mounted) Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Taste profile reset.", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: noirColor),
                );
              }
            },
            child: Text("RESET", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showResetJourneyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(side: BorderSide(color: noirColor, width: 2)),
        title: Text("RESET CINEMA JOURNEY?", style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
        content: Text("This will permanently wipe all your films, series, and spotlight entries. This cannot be undone.",
            style: TextStyle(color: noirColor, fontSize: 12, fontWeight: FontWeight.w500)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCEL", style: TextStyle(color: noirColor))),
          TextButton(
            onPressed: () async {
              await WatchlistService().resetCinemaJourney();
              if (context.mounted) Navigator.pop(context);
            },
            child: Text("RESET ALL", style: TextStyle(color: accentColor)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(User? user) {
    if (user == null) return;
    final passwordController = TextEditingController();
    // Detect if email/password user
    final hasPassword = user.providerData.any((p) => p.providerId == 'password');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(side: BorderSide(color: accentColor, width: 2)),
        title: Text("DELETE ACCOUNT", style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "This will permanently delete your account, all your media, playlists, posts, and profile data. This action cannot be reversed.",
              style: TextStyle(color: noirColor, fontSize: 12, fontWeight: FontWeight.w500, height: 1.5),
            ),
            if (hasPassword) ...[
              SizedBox(height: 16),
              Text("Enter your password to confirm:", style: TextStyle(color: noirColor, fontSize: 11, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              TextField(
                controller: passwordController,
                obscureText: true,
                autofocus: true,
                style: TextStyle(color: noirColor),
                decoration: InputDecoration(
                  hintText: "Password",
                  hintStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentColor, width: 2)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accentColor, width: 2)),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCEL", style: TextStyle(color: noirColor))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDeleteAccount(user, hasPassword, passwordController.text);
            },
            child: Text("DELETE FOREVER", style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteAccount(User user, bool hasPassword, String password) async {
    try {
      // Re-authenticate first
      if (hasPassword) {
        if (password.isEmpty) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Password required."), backgroundColor: accentColor));
          return;
        }
        final credential = EmailAuthProvider.credential(email: user.email!, password: password);
        await user.reauthenticateWithCredential(credential);
      } else {
        // Google re-auth
        final googleSignIn = await _reAuthWithGoogle();
        if (!googleSignIn) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Re-authentication failed."), backgroundColor: accentColor));
          return;
        }
      }

      // Wipe all user data in Firestore
      final uid = user.uid;
      final batch = FirebaseFirestore.instance.batch();
      final collectionsToDelete = ['movies', 'top_five', 'taste_profile', 'notifications'];
      for (final col in collectionsToDelete) {
        final snap = await FirebaseFirestore.instance.collection('users').doc(uid).collection(col).get();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
      }
      batch.delete(FirebaseFirestore.instance.collection('users').doc(uid));
      await batch.commit();

      // Delete Firebase Auth account
      await user.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Account deleted successfully."), backgroundColor: noirColor),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? "Deletion failed. Please try again."), backgroundColor: accentColor),
        );
      }
    }
  }

  Future<bool> _reAuthWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return false;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.currentUser?.reauthenticateWithCredential(credential);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(side: BorderSide(color: noirColor, width: 2)),
        title: Text("ABOUT SCREENIQUE", style: TextStyle(color: noirColor, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Version 1.0.0", style: TextStyle(color: noirColor, fontWeight: FontWeight.w900, fontSize: 14)),
            SizedBox(height: 8),
            Text(
              "Screenique is your personal cinematic archive — track films and series, discover hidden gems through AI recommendations, and connect with fellow cinema lovers in the community space.",
              style: TextStyle(color: noirColor.withOpacity(0.75), fontSize: 12, height: 1.6),
            ),
            SizedBox(height: 16),
            Text("Data powered by TMDB API.", style: TextStyle(color: noirColor.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("CLOSE", style: TextStyle(color: noirColor, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(side: BorderSide(color: noirColor, width: 2)),
        title: Text("Sign Out", style: TextStyle(color: noirColor, fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to sign out?", style: TextStyle(color: noirColor, fontSize: 12, fontWeight: FontWeight.w500)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCEL", style: TextStyle(color: noirColor))),
          TextButton(
            onPressed: () {
              AuthService().signOut();
              Navigator.pop(context);
            },
            child: Text("SIGN OUT", style: TextStyle(color: accentColor)),
          ),
        ],
      ),
    );
  }
}
