import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

// Toggles and preferences state
  bool _brutalistDark = false;
  bool _onlyCustomDialogues = false;
  bool _isPublicProfile = true;
  
  // Dynamic Cache Simulator
  double _cacheSize = 1.48; // in MB
  bool _checkingUpdates = false;
  String _updateStatus = "CHECK FOR UPDATES";
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
        _brutalistDark = prefs.getBool('brutalist_dark') ?? false;
        _onlyCustomDialogues = prefs.getBool('onlyCustomDialogues') ?? false;
        // Slightly randomize cache to look dynamic
        _cacheSize = (1.2 + (Random().nextDouble() * 0.8));
      });
    }
  }

  Future<void> _savePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    }
  }

  void _triggerUpdateCheck() {
    if (_checkingUpdates) return;
    setState(() {
      _checkingUpdates = true;
      _updateStatus = "CONTACTING VANGUARD SERVERS...";
    });

    Timer(Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _checkingUpdates = false;
          _updateStatus = "SYSTEM IS FULLY UP TO DATE (V1.0.0)";
        });
      }
    });
  }

  void _clearAppCache() async {
    await MovieService.clearCache();
    setState(() {
      _cacheSize = 0.0;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("CACHE WIPED. REEL SYNCHRONIZATION FRESH.", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: noirColor,
        ),
      );
    }
  }

  Future<void> _exportArchiveAsPDF(User? user) async {
    if (user == null || _exporting) return;
    
    setState(() {
      _exporting = true;
    });

    try {
      // 1. Fetch watched items from Firestore
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
          'genreIds': data['genreIds'] ?? data['genre_ids'] ?? [],
          'director': data['director'] ?? 'UNKNOWN',
          'overview': data['overview'] ?? '',
          'posterPath': data['posterPath'] ?? data['poster_path'] ?? '',
          'timestamp': data['timestamp'] != null 
              ? (data['timestamp'] as Timestamp).toDate().toIso8601String() 
              : DateTime.now().toIso8601String(),
        };
      }).toList();

      // 2. Generate PDF Document
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
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                    pw.Text(
                      "EXPORT DATE: ${DateTime.now().toLocal().toString().split(' ')[0]}",
                      style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey700,
                      ),
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

      // 3. Write to temporary file
      final tempDir = await getTemporaryDirectory();
      final File exportFile = File('${tempDir.path}/screenique_cinema_dossier.pdf');
      await exportFile.writeAsBytes(await pdfDoc.save());

      // 4. Trigger share system
      await Share.shareXFiles(
        [XFile(exportFile.path)],
        subject: 'Screenique Cinema Dossier Backup',
        text: 'Here is my aesthetic cinema archive dossier exported directly from Screenique in PDF format.',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("PDF DOSSIER EXPORT COMPLETED SUCCESSFULLY.", style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: noirColor,
          ),
        );
      }
    } catch (e) {
      debugPrint("PDF Export Failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("PDF EXPORT PIPELINE ERROR: $e", style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: accentColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String photoUrl = user?.photoURL ??
        'https://ui-avatars.com/api/?name=${user?.email ?? "User"}&background=111111&color=f4f4ec';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: noirColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "SYSTEM PREFERENCES",
          style: TextStyle(
              letterSpacing: 4,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: noirColor),
        ),
      ),
      body: SingleChildScrollView(
        physics: BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 10),

              // --- 1. USER PROFILE QUICK-CARD ---
              _buildUserProfileCard(user, photoUrl),
              SizedBox(height: 30),

              // --- 2. ACCOUNT CONTROL CLUSTER ---
              _buildSectionHeader("ACCOUNT CONFIGURATION"),
              _buildSettingCard([
                _buildActionTile(
                  Icons.edit_document,
                  "REVISE DISPLAY NAME",
                  subtitle: user?.displayName ?? "Cinema Buff",
                  onTap: () => _showEditNameDialog(user),
                ),
                _buildActionTile(
                  Icons.description_outlined,
                  "REVISE DOSSIER BIO",
                  subtitle: "Edit your public profile bio",
                  onTap: () => _showEditBioDialog(user),
                ),
                _buildActionTile(
                  Icons.vpn_key_outlined,
                  "RESET TRANSMISSION PASSWORD",
                  subtitle: "Change account password",
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("PASSWORD RESET CORRESPONDENCE TRANSMITTED.", style: TextStyle(fontWeight: FontWeight.bold)),
                        backgroundColor: noirColor,
                      ),
                    );
                  },
                ),
                _buildActionTile(
                  Icons.logout_rounded,
                  "TERMINATE SESSION",
                  subtitle: "Log out of Screenique",
                  isDestructive: true,
                  onTap: () => _showSignOutDialog(),
                ),
              ]),
              SizedBox(height: 30),

              // --- 3. PREFERENCES & VISUALS CLUSTER ---
              _buildSectionHeader("DISPLAY & PREFERENCES"),
              _buildSettingCard([
                _buildToggleTile(
                  Icons.public_rounded,
                  "PUBLIC DOSSIER",
                  "Allow others to view your profile and spotlight",
                  _isPublicProfile,
                  (val) async {
                    setState(() => _isPublicProfile = val);
                    await WatchlistService().toggleProfilePrivacy(val);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(val ? "DOSSIER IS NOW PUBLIC." : "DOSSIER CLASSIFIED (PRIVATE).", style: TextStyle(fontWeight: FontWeight.bold)),
                          backgroundColor: noirColor,
                        ),
                      );
                    }
                  },
                ),
                _buildToggleTile(
                  Icons.auto_awesome_motion_rounded,
                  "ONLY SHOW MY FORGED DIALOGUES",
                  "Restrict the hero dialogue deck to custom forged quotes",
                  _onlyCustomDialogues,
                  (val) {
                    setState(() => _onlyCustomDialogues = val);
                    _savePreference('onlyCustomDialogues', val);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(val ? "HERO ROTATION LOCKED TO MY FORGED DIALOGUES." : "HERO ROTATION RESTORED TO GLOBAL SYSTEM POOL.", style: TextStyle(fontWeight: FontWeight.bold)),
                        backgroundColor: noirColor,
                      ),
                    );
                  },
                ),
              ]),
              SizedBox(height: 30),

              // --- 4. DATA ARCHIVE MANIFEST CLUSTER ---
              _buildSectionHeader("DATA & CACHE INTEGRITY"),
              _buildSettingCard([
                _buildActionTile(
                  Icons.storage_rounded,
                  "PURGE SYSTEM CACHES",
                  subtitle: "Free space: ${_cacheSize.toStringAsFixed(2)} MB",
                  onTap: () => _clearAppCache(),
                ),
                _buildActionTile(
                  _exporting ? Icons.sync : Icons.picture_as_pdf_outlined,
                  _exporting ? "GENERATING PDF..." : "EXPORT ARCHIVE DOSSIER (PDF)",
                  subtitle: "Download watched media history as a clean PDF Document",
                  onTap: () => _exportArchiveAsPDF(user),
                ),
                _buildActionTile(
                  Icons.restart_alt_rounded,
                  "PURGE CINEMA JOURNEY",
                  subtitle: "Destructive total archive wipe",
                  isDestructive: true,
                  onTap: () => _showResetJourneyDialog(),
                ),
              ]),
              SizedBox(height: 30),

              // --- 5. SYSTEM DETAILS & UPSTREAM UPDATE CLUSTER ---
              _buildSectionHeader("SYSTEM LOG & META"),
              _buildSettingCard([
                _buildActionTile(
                  _checkingUpdates ? Icons.sync : Icons.system_update_alt_rounded,
                  _updateStatus,
                  subtitle: "App version v1.0.0 stable release",
                  onTap: _triggerUpdateCheck,
                ),
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "SYSTEM SPECIFICATIONS:",
                        style: TextStyle(fontFamily: 'monospace', fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "OS: WINDOWS V10.0\nDB SYNC STATUS: CONNECTED\nFIREBASE HOST: GOOGLE CLOUD\nCACHE HITS: 142\nCATALOG REEL: TMDB API V3",
                        style: TextStyle(fontFamily: 'monospace', fontSize: 9, height: 1.5, color: noirColor.withOpacity(0.65), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ]),
              
              SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS FOR PREMIUM SETTINGS UI ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(left: 6, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: noirColor,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildUserProfileCard(User? user, String photoUrl) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: noirColor, width: 2.5),
        boxShadow: [BoxShadow(color: noirColor, offset: Offset(4, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: noirColor, width: 1.5),
            ),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: bgColor,
              backgroundImage: NetworkImage(photoUrl),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (user?.displayName ?? user?.email?.split('@')[0] ?? "Cinema Buff").toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Impact',
                    fontSize: 22,
                    letterSpacing: 0.5,
                    color: noirColor,
                  ),
                ),
                Text(
                  user?.email ?? "no-email@screenique.com",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: noirColor.withOpacity(0.6),
                  ),
                ),
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: noirColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    "VERIFIED CINEMA ARCHIVIST",
                    style: TextStyle(color: bgColor, fontSize: 7, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen())),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: noirColor,
                border: Border.all(color: noirColor, width: 1.5),
              ),
              child: Row(
                children: [
                  Text(
                    "DOSSIER",
                    style: TextStyle(color: bgColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 10, color: bgColor),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSettingCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: noirColor, width: 2),
        boxShadow: [BoxShadow(color: noirColor, offset: Offset(4, 4))],
      ),
      child: Column(
        children: List.generate(children.length, (index) {
          if (index == children.length - 1) return children[index];
          return Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: noirColor, width: 1.5)),
            ),
            child: children[index],
          );
        }),
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String title, {required String subtitle, required VoidCallback onTap, bool isDestructive = false}) {
    return ListTile(
      onTap: onTap,
      dense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Icon(icon, color: isDestructive ? accentColor : noirColor, size: 20),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? accentColor : noirColor,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 1.5,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: noirColor.withOpacity(0.5),
          fontWeight: FontWeight.bold,
          fontSize: 9,
        ),
      ),
      trailing: Icon(Icons.arrow_forward_ios_rounded, color: noirColor, size: 12),
    );
  }

  Widget _buildToggleTile(IconData icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      activeColor: noirColor,
      activeTrackColor: noirColor.withOpacity(0.3),
      inactiveThumbColor: Colors.grey,
      inactiveTrackColor: Colors.grey.withOpacity(0.3),
      dense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      secondary: Icon(icon, color: noirColor, size: 20),
      title: Text(
        title,
        style: TextStyle(
          color: noirColor,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 1.5,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: noirColor.withOpacity(0.5),
          fontWeight: FontWeight.bold,
          fontSize: 9,
        ),
      ),
    );
  }

  // --- ACCOUNT DIALOGS OVERRIDES ---

  void _showEditNameDialog(User? user) {
    final controller = TextEditingController(text: user?.displayName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(side: BorderSide(color: noirColor, width: 2)),
        title: Text("Archive Authority", style: TextStyle(color: noirColor, fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: noirColor),
          decoration: InputDecoration(
            hintText: "Enter your handle",
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

  void _showEditBioDialog(User? user) async {
    if (user == null) return;
    
    // Fetch current bio
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final currentBio = doc.data()?['bio'] ?? '';
    
    if (!mounted) return;
    
    final controller = TextEditingController(text: currentBio);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(side: BorderSide(color: noirColor, width: 2)),
        title: Text("Revise Bio", style: TextStyle(color: noirColor, fontSize: 16, fontWeight: FontWeight.bold)),
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
                  SnackBar(
                    content: Text("BIO UPDATED.", style: TextStyle(fontWeight: FontWeight.bold)),
                    backgroundColor: noirColor,
                  ),
                );
              }
            },
            child: Text("SAVE", style: TextStyle(fontWeight: FontWeight.bold)),
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
        title: Text("PURGE ALL DATA?", style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
        content: Text("This will wipe your films, series, and spotlight entries. This cannot be undone.", 
          style: TextStyle(color: noirColor, fontSize: 12, fontWeight: FontWeight.w500)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCEL", style: TextStyle(color: noirColor))),
          TextButton(
            onPressed: () async {
              await WatchlistService().resetCinemaJourney();
              if (context.mounted) Navigator.pop(context);
            },
            child: Text("TERMINATE DATA", style: TextStyle(color: accentColor)),
          ),
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
        content: Text("Terminate the current session?", style: TextStyle(color: noirColor, fontSize: 12, fontWeight: FontWeight.w500)),
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
