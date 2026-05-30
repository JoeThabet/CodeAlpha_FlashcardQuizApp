import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() {
  runApp(const FlashcardApp());
}

// ── Model ──────────────────────────────────────────────────────────────────────

class Flashcard {
  final String id;
  String question;
  String answer;

  Flashcard({required this.id, required this.question, required this.answer});

  factory Flashcard.fromJson(Map<String, dynamic> json) =>
      Flashcard(id: json['id'], question: json['question'], answer: json['answer']);

  Map<String, dynamic> toJson() => {'id': id, 'question': question, 'answer': answer};
}

// ── Storage ────────────────────────────────────────────────────────────────────

class CardStorage {
  static const _key = 'flashcards_v2';

  static Future<List<Flashcard>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return _defaults();
    return (jsonDecode(raw) as List).map((e) => Flashcard.fromJson(e)).toList();
  }

  static Future<void> save(List<Flashcard> cards) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(cards.map((c) => c.toJson()).toList()));
  }

  static List<Flashcard> _defaults() => [
        Flashcard(id: const Uuid().v4(), question: 'What is Flutter?', answer: 'An open-source UI toolkit by Google for building natively compiled applications for mobile, web, and desktop from a single codebase.'),
        Flashcard(id: const Uuid().v4(), question: 'What language does Flutter use?', answer: 'Dart — a strongly typed, object-oriented language optimised for fast, cross-platform UI development.'),
        Flashcard(id: const Uuid().v4(), question: 'What is a Widget?', answer: 'The fundamental building block of Flutter UI. Every visual element — buttons, text, layouts — is a widget.'),
        Flashcard(id: const Uuid().v4(), question: 'StatelessWidget vs StatefulWidget?', answer: 'StatelessWidget is immutable and never rebuilds on its own. StatefulWidget holds mutable state and can call setState() to trigger UI updates.'),
        Flashcard(id: const Uuid().v4(), question: 'What is Hot Reload?', answer: 'A Flutter feature that injects updated source code into the Dart VM instantly, so you see UI changes without restarting the app.'),
      ];
}

// ── Theme ──────────────────────────────────────────────────────────────────────

class AppTheme {
  static const bg = Color(0xFF0D0D14);
  static const surface = Color(0xFF16161F);
  static const card = Color(0xFF1E1E2C);
  static const accent = Color(0xFF7C6EF7);
  static const accentLight = Color(0xFF9D91FF);
  static const textPrimary = Color(0xFFF0F0FF);
  static const textSecondary = Color(0xFF8B8BA8);
  static const divider = Color(0xFF2A2A3C);
  static const success = Color(0xFF3DD68C);
  static const error = Color(0xFFFF6B6B);

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: bg,
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.dark(
          primary: accent,
          surface: surface,
          error: error,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: bg,
          foregroundColor: textPrimary,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: card,
          labelStyle: const TextStyle(color: textSecondary),
          hintStyle: const TextStyle(color: textSecondary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: accent, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
      );
}

// ── App ────────────────────────────────────────────────────────────────────────

class FlashcardApp extends StatelessWidget {
  const FlashcardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlashMind',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const HomeScreen(),
    );
  }
}

// ── Home Screen ────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Flashcard> _cards = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cards = await CardStorage.load();
    setState(() { _cards = cards; _loading = false; });
  }

  Future<void> _save() => CardStorage.save(_cards);

  void _startQuiz() {
    if (_cards.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => QuizScreen(cards: List.from(_cards))));
  }

  void _addCard() async {
    final result = await Navigator.push(context, MaterialPageRoute<Flashcard>(builder: (_) => const EditCardScreen()));
    if (result != null) { setState(() => _cards.add(result)); await _save(); }
  }

  void _editCard(int i) async {
    final result = await Navigator.push(context, MaterialPageRoute<Flashcard>(builder: (_) => EditCardScreen(card: _cards[i])));
    if (result != null) { setState(() => _cards[i] = result); await _save(); }
  }

  void _deleteCard(int i) async {
    HapticFeedback.mediumImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Delete card?',
        message: 'This cannot be undone.',
        confirmLabel: 'Delete',
        confirmColor: AppTheme.error,
      ),
    );
    if (confirm == true) { setState(() => _cards.removeAt(i)); await _save(); }
  }

  Route<dynamic> _route(Widget page) =>
      PageRouteBuilder(pageBuilder: (_, __, ___) => page, transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: SlideTransition(
            position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(
                CurvedAnimation(parent: a, curve: Curves.easeOut)), child: child)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
            : CustomScrollView(
                slivers: [
                  // ── Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('FlashMind',
                                      style: TextStyle(
                                          color: AppTheme.accent,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1.5)),
                                  const SizedBox(height: 4),
                                  const Text('Your Study Deck',
                                      style: TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5)),
                                ],
                              ),
                              _IconBtn(
                                icon: Icons.add_rounded,
                                onTap: _addCard,
                                tooltip: 'Add card',
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Stats row
                          Row(
                            children: [
                              _StatPill(label: '${_cards.length}', sublabel: 'Cards', color: AppTheme.accent),
                              const SizedBox(width: 10),
                              _StatPill(label: '${(_cards.length / 5).ceil()}', sublabel: 'Min to review', color: AppTheme.success),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Start button
                          if (_cards.isNotEmpty) _StartButton(onTap: _startQuiz),
                          const SizedBox(height: 32),
                          const Text('ALL CARDS',
                              style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.8)),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  // ── Card list
                  _cards.isEmpty
                      ? SliverFillRemaining(child: _EmptyState(onAdd: _addCard))
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => Padding(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                              child: _CardTile(
                                card: _cards[i],
                                index: i,
                                onEdit: () => _editCard(i),
                                onDelete: () => _deleteCard(i),
                              ),
                            ),
                            childCount: _cards.length,
                          ),
                        ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
      ),
    );
  }
}

// ── Start Button ───────────────────────────────────────────────────────────────

class _StartButton extends StatelessWidget {
  final VoidCallback onTap;
  const _StartButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C6EF7), Color(0xFF5B4EDB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: AppTheme.accent.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text('Start Quiz', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
          ],
        ),
      ),
    );
  }
}

// ── Card Tile ──────────────────────────────────────────────────────────────────

class _CardTile extends StatelessWidget {
  final Flashcard card;
  final int index;
  final VoidCallback onEdit, onDelete;

  const _CardTile({required this.card, required this.index, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text('${index + 1}',
                        style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(card.question,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600, height: 1.4)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(58, 8, 18, 0),
            child: Text(card.answer,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5)),
          ),
          const SizedBox(height: 8),
          const Divider(color: AppTheme.divider, height: 1),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 15),
                  label: const Text('Edit', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
              Container(width: 1, height: 20, color: AppTheme.divider),
              Expanded(
                child: TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 15),
                  label: const Text('Delete', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.error,
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Quiz Screen ────────────────────────────────────────────────────────────────

class QuizScreen extends StatefulWidget {
  final List<Flashcard> cards;
  const QuizScreen({super.key, required this.cards});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
  int _index = 0;
  bool _flipped = false;
  late AnimationController _flipCtrl;
  late AnimationController _slideCtrl;
  late Animation<double> _flipAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _flipAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOutCubic));
    _slideAnim = Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _slideCtrl.forward();
  }

  @override
  void dispose() { _flipCtrl.dispose(); _slideCtrl.dispose(); super.dispose(); }

  void _flip() {
    HapticFeedback.selectionClick();
    if (_flipped) { _flipCtrl.reverse(); } else { _flipCtrl.forward(); }
    setState(() => _flipped = !_flipped);
  }

  void _navigate(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.cards.length) return;
    HapticFeedback.lightImpact();
    _flipCtrl.reset();
    _slideCtrl.reset();
    setState(() { _index = next; _flipped = false; });
    _slideCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.cards[_index];
    final progress = (_index + 1) / widget.cards.length;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('${_index + 1} / ${widget.cards.length}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.w500)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Text('${(progress * 100).toInt()}%',
                style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            children: [
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: AppTheme.divider,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
                ),
              ),
              const SizedBox(height: 32),
              // Flip card
              Expanded(
                child: SlideTransition(
                  position: _slideAnim,
                  child: GestureDetector(
                    onTap: _flip,
                    child: AnimatedBuilder(
                      animation: _flipAnim,
                      builder: (_, __) {
                        final isBack = _flipAnim.value > 0.5;
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateY(pi * _flipAnim.value),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isBack ? const Color(0xFF1A2535) : AppTheme.card,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                  color: isBack
                                      ? AppTheme.accent.withOpacity(0.4)
                                      : AppTheme.divider,
                                  width: isBack ? 1.5 : 1),
                              boxShadow: [
                                BoxShadow(
                                    color: isBack
                                        ? AppTheme.accent.withOpacity(0.12)
                                        : Colors.black.withOpacity(0.3),
                                    blurRadius: 30,
                                    offset: const Offset(0, 12)),
                              ],
                            ),
                            padding: const EdgeInsets.all(36),
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..rotateY(isBack ? pi : 0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isBack
                                          ? AppTheme.accent.withOpacity(0.15)
                                          : AppTheme.textSecondary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      isBack ? 'ANSWER' : 'QUESTION',
                                      style: TextStyle(
                                        color: isBack ? AppTheme.accentLight : AppTheme.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  Text(
                                    isBack ? card.answer : card.question,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isBack ? AppTheme.accentLight : AppTheme.textPrimary,
                                      fontSize: isBack ? 17 : 20,
                                      fontWeight: isBack ? FontWeight.w500 : FontWeight.w700,
                                      height: 1.55,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Hint
              Text(
                _flipped ? 'Tap card to see question again' : 'Tap card to reveal answer',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              // Show Answer button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: _flip,
                  icon: Icon(_flipped ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                  label: Text(_flipped ? 'Hide Answer' : 'Show Answer',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accent,
                    side: const BorderSide(color: AppTheme.accent, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Navigation
              Row(
                children: [
                  Expanded(
                    child: _NavButton(
                      icon: Icons.arrow_back_rounded,
                      label: 'Previous',
                      onTap: _index > 0 ? () => _navigate(-1) : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _NavButton(
                      icon: Icons.arrow_forward_rounded,
                      label: 'Next',
                      onTap: _index < widget.cards.length - 1 ? () => _navigate(1) : null,
                      iconRight: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool iconRight;

  const _NavButton({required this.icon, required this.label, this.onTap, this.iconRight = false});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: enabled ? AppTheme.card : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: iconRight
              ? [
                  Text(label, style: TextStyle(color: enabled ? AppTheme.textPrimary : AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(width: 6),
                  Icon(icon, size: 18, color: enabled ? AppTheme.textPrimary : AppTheme.textSecondary),
                ]
              : [
                  Icon(icon, size: 18, color: enabled ? AppTheme.textPrimary : AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(label, style: TextStyle(color: enabled ? AppTheme.textPrimary : AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 14)),
                ],
        ),
      ),
    );
  }
}

// ── Edit / Add Screen ──────────────────────────────────────────────────────────

class EditCardScreen extends StatefulWidget {
  final Flashcard? card;
  const EditCardScreen({super.key, this.card});
  @override
  State<EditCardScreen> createState() => _EditCardScreenState();
}

class _EditCardScreenState extends State<EditCardScreen> {
  late final TextEditingController _qCtrl;
  late final TextEditingController _aCtrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _qCtrl = TextEditingController(text: widget.card?.question ?? '');
    _aCtrl = TextEditingController(text: widget.card?.answer ?? '');
  }

  @override
  void dispose() { _qCtrl.dispose(); _aCtrl.dispose(); super.dispose(); }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, Flashcard(
      id: widget.card?.id ?? const Uuid().v4(),
      question: _qCtrl.text.trim(),
      answer: _aCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.card != null;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Card' : 'New Card'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: _save,
              child: Text(isEdit ? 'Save' : 'Add',
                  style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _label('Question'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _qCtrl,
              maxLines: 4,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              decoration: const InputDecoration(hintText: 'Type your question here...'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Question cannot be empty' : null,
            ),
            const SizedBox(height: 28),
            _label('Answer'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _aCtrl,
              maxLines: 5,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              decoration: const InputDecoration(hintText: 'Type the answer here...'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Answer cannot be empty' : null,
            ),
            const SizedBox(height: 36),
            GestureDetector(
              onTap: _save,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C6EF7), Color(0xFF5B4EDB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: AppTheme.accent.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: Center(
                  child: Text(isEdit ? 'Save Changes' : 'Add Flashcard',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.4),
  );
}

// ── Empty State ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
            ),
            child: const Icon(Icons.style_rounded, color: AppTheme.accent, size: 36),
          ),
          const SizedBox(height: 20),
          const Text('No cards yet', style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Add your first flashcard to get started', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
              ),
              child: const Text('+ Add Card', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  const _IconBtn({required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Icon(icon, color: AppTheme.textPrimary, size: 20),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label, sublabel;
  final Color color;
  const _StatPill({required this.label, required this.sublabel, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          Text(sublabel, style: TextStyle(color: color.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String title, message, confirmLabel;
  final Color confirmColor;
  const _ConfirmDialog({required this.title, required this.message, required this.confirmLabel, required this.confirmColor});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
      content: Text(message, style: const TextStyle(color: AppTheme.textSecondary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel, style: TextStyle(color: confirmColor, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
