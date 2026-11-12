import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const MyApp());
}

// =====================================================
// API SERVICE
// =====================================================

class Api {
  static String? token;

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    // Android emulator reaches the host computer through 10.0.2.2.
    return 'http://10.0.2.2:3000';
  }

  static Map<String, String> headers() {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Map<String, dynamic> _decodeObject(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return <String, dynamic>{'message': response.body};
  }

  static String _errorMessage(http.Response response) {
    try {
      final data = _decodeObject(response);
      return (data['message'] ?? 'Request failed (${response.statusCode})')
          .toString();
    } catch (_) {
      return 'Request failed (${response.statusCode}): ${response.body}';
    }
  }

  static Future<String> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/login'),
      headers: headers(),
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response));
    }

    final data = _decodeObject(response);
    final value = data['token'];
    if (value == null || value.toString().isEmpty) {
      throw Exception('Login response did not contain a token.');
    }
    return value.toString();
  }

  static Future<List<dynamic>> getLecturers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/lecturers'),
      headers: headers(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw Exception('Unexpected lecturer list response from server.');
    }
    return decoded;
  }

  static Future<void> addLecturer(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/lecturers'),
      headers: headers(),
      body: jsonEncode(data),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response));
    }
  }

  static Future<void> updateLecturer(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/lecturers/${Uri.encodeComponent(id)}'),
      headers: headers(),
      body: jsonEncode(data),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response));
    }
  }

  static Future<void> deleteLecturer(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/lecturers/${Uri.encodeComponent(id)}'),
      headers: headers(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response));
    }
  }
}

// =====================================================
// IMAGE HELPERS
// =====================================================

Uint8List? decodeImage(String? image) {
  if (image == null || image.isEmpty) return null;

  try {
    final base64String =
        image.contains(',') ? image.split(',').last : image;
    return base64Decode(base64String);
  } catch (_) {
    return null;
  }
}

Widget lecturerAvatar(String? image, {double size = 50}) {
  final bytes = decodeImage(image);

  if (bytes != null) {
    return ClipOval(
      child: Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) {
          return Icon(Icons.person, size: size);
        },
      ),
    );
  }

  return CircleAvatar(
    radius: size / 2,
    child: const Icon(Icons.person),
  );
}

// =====================================================
// MAIN APPLICATION
// =====================================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'QLHocPhan',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool loggedIn = false;

  void handleLogin(String value) {
    Api.token = value;
    setState(() => loggedIn = true);
  }

  void handleLogout() {
    Api.token = null;
    setState(() => loggedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loggedIn) {
      return LecturerPage(onLogout: handleLogout);
    }
    return LoginPage(onLogin: handleLogin);
  }
}

// =====================================================
// LOGIN PAGE
// =====================================================

class LoginPage extends StatefulWidget {
  final ValueChanged<String> onLogin;

  const LoginPage({super.key, required this.onLogin});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool hidePassword = true;

  Future<void> login() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final value = await Api.login(
        emailController.text.trim(),
        passwordController.text,
      );

      if (!mounted) return;
      widget.onLogin(value);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 400,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.school,
                      size: 65,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'QLHocPhan',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text('Administrator Login'),
                    const SizedBox(height: 25),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: passwordController,
                      obscureText: hidePassword,
                      onSubmitted: (_) {
                        if (!loading) login();
                      },
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            hidePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() => hidePassword = !hidePassword);
                          },
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: loading ? null : login,
                        child: loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('LOGIN'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// LECTURER MANAGEMENT PAGE
// =====================================================

class LecturerPage extends StatefulWidget {
  final VoidCallback onLogout;

  const LecturerPage({super.key, required this.onLogout});

  @override
  State<LecturerPage> createState() => _LecturerPageState();
}

class _LecturerPageState extends State<LecturerPage> {
  List<dynamic> lecturers = [];
  bool loading = true;

  String searchQuery = '';
  String sortBy = 'name_asc';
  final TextEditingController searchController = TextEditingController();

  List<dynamic> get filteredLecturers {
    final query = searchQuery.toLowerCase().trim();

    final list = lecturers.where((item) {
      final lecturer = item as Map<String, dynamic>;
      final name = (lecturer['Fullname'] ?? '').toString().toLowerCase();
      final id = (lecturer['IDGV'] ?? '').toString().toLowerCase();
      return name.contains(query) || id.contains(query);
    }).toList();

    list.sort((a, b) {
      final mapA = a as Map<String, dynamic>;
      final mapB = b as Map<String, dynamic>;

      switch (sortBy) {
        case 'name_desc':
          return (mapB['Fullname'] ?? '')
              .toString()
              .compareTo((mapA['Fullname'] ?? '').toString());
        case 'class_desc':
          return (int.tryParse('${mapB['SumClass'] ?? 0}') ?? 0)
              .compareTo(int.tryParse('${mapA['SumClass'] ?? 0}') ?? 0);
        case 'class_asc':
          return (int.tryParse('${mapA['SumClass'] ?? 0}') ?? 0)
              .compareTo(int.tryParse('${mapB['SumClass'] ?? 0}') ?? 0);
        case 'name_asc':
        default:
          return (mapA['Fullname'] ?? '')
              .toString()
              .compareTo((mapB['Fullname'] ?? '').toString());
      }
    });

    return list;
  }

  @override
  void initState() {
    super.initState();
    loadLecturers();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadLecturers({bool showLoading = true}) async {
    if (!mounted) return;

    if (showLoading) {
      setState(() => loading = true);
    }

    try {
      final result = await Api.getLecturers();
      if (!mounted) return;

      setState(() {
        lecturers = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);
      showMessage(e.toString());
    }
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> showLecturerForm({
    Map<String, dynamic>? lecturer,
  }) async {
    final editing = lecturer != null;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return LecturerFormDialog(
          lecturer: lecturer,
        );
      },
    );

    if (saved == true && mounted) {
      await loadLecturers(showLoading: false);
      if (!mounted) return;

      showMessage(
        editing
            ? 'Lecturer updated successfully'
            : 'Lecturer added successfully',
      );
    }
  }

  Future<void> deleteLecturer(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Lecturer'),
        content: Text('Delete lecturer $id?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await Api.deleteLecturer(id);
      if (!mounted) return;

      await loadLecturers(showLoading: false);
      if (!mounted) return;

      showMessage('Lecturer deleted successfully');
    } catch (e) {
      if (!mounted) return;
      showMessage(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayList = filteredLecturers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lecturer Management'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => loadLecturers(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: 'Search by Name or ID...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      searchController.clear();
                                      setState(() => searchQuery = '');
                                    },
                                  )
                                : null,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() => searchQuery = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: sortBy,
                          decoration: const InputDecoration(
                            labelText: 'Sort by',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'name_asc',
                              child: Text('Name (A - Z)'),
                            ),
                            DropdownMenuItem(
                              value: 'name_desc',
                              child: Text('Name (Z - A)'),
                            ),
                            DropdownMenuItem(
                              value: 'class_desc',
                              child: Text('Classes (High - Low)'),
                            ),
                            DropdownMenuItem(
                              value: 'class_asc',
                              child: Text('Classes (Low - High)'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => sortBy = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: displayList.isEmpty
                      ? const Center(child: Text('No lecturers found'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: displayList.length,
                          itemBuilder: (context, index) {
                            final lecturer =
                                displayList[index] as Map<String, dynamic>;
                            final id = (lecturer['IDGV'] ?? '').toString();

                            return Card(
                              child: ListTile(
                                leading: lecturerAvatar(
                                  lecturer['Image']?.toString(),
                                  size: 55,
                                ),
                                title: Text(
                                  (lecturer['Fullname'] ?? '').toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'ID: $id | Classes: ${lecturer['SumClass'] ?? 0}',
                                ),
                                trailing: Wrap(
                                  spacing: 0,
                                  children: [
                                    IconButton(
                                      tooltip: 'Edit',
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () =>
                                          showLecturerForm(lecturer: lecturer),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete',
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => deleteLecturer(id),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showLecturerForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Lecturer'),
      ),
    );
  }
}

// =====================================================
// ADD / EDIT LECTURER DIALOG
// The dialog owns its controllers and disposes them with
// its State, after the dialog route has finished closing.
// =====================================================

class LecturerFormDialog extends StatefulWidget {
  final Map<String, dynamic>? lecturer;

  const LecturerFormDialog({
    super.key,
    this.lecturer,
  });

  @override
  State<LecturerFormDialog> createState() => _LecturerFormDialogState();
}

class _LecturerFormDialogState extends State<LecturerFormDialog> {
  late final TextEditingController idController;
  late final TextEditingController nameController;
  late final TextEditingController classController;

  final formKey = GlobalKey<FormState>();

  String image = '';
  XFile? selectedImage;
  Uint8List? previewBytes;
  bool saving = false;
  bool pickingImage = false;

  bool get editing => widget.lecturer != null;

  @override
  void initState() {
    super.initState();

    final lecturer = widget.lecturer;

    idController = TextEditingController(
      text: lecturer?['IDGV']?.toString() ?? '',
    );
    nameController = TextEditingController(
      text: lecturer?['Fullname']?.toString() ?? '',
    );
    classController = TextEditingController(
      text: lecturer?['SumClass']?.toString() ?? '',
    );
    image = lecturer?['Image']?.toString() ?? '';
  }

  @override
  void dispose() {
    idController.dispose();
    nameController.dispose();
    classController.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    if (pickingImage || saving) return;

    setState(() => pickingImage = true);

    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 600,
        maxHeight: 600,
      );

      if (!mounted) return;

      if (file != null) {
        final bytes = await file.readAsBytes();
        if (!mounted) return;

        setState(() {
          selectedImage = file;
          previewBytes = bytes;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not select image: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => pickingImage = false);
      }
    }
  }

  Future<void> saveLecturer() async {
    if (saving) return;

    final valid = formKey.currentState?.validate() ?? false;
    if (!valid) return;

    if (selectedImage == null && image.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      var finalImage = image;

      if (selectedImage != null) {
        final bytes = await selectedImage!.readAsBytes();
        if (!mounted) return;

        final mime = selectedImage!.mimeType ?? 'image/jpeg';
        finalImage = 'data:$mime;base64,${base64Encode(bytes)}';
      }

      final data = <String, dynamic>{
        'IDGV': idController.text.trim(),
        'Fullname': nameController.text.trim(),
        'Image': finalImage,
        'SumClass': int.parse(classController.text.trim()),
      };

      if (editing) {
        await Api.updateLecturer(idController.text.trim(), data);
      } else {
        await Api.addLecturer(data);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
      setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(editing ? 'Edit Lecturer' : 'Add Lecturer'),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: idController,
                  readOnly: editing,
                  decoration: const InputDecoration(
                    labelText: 'Lecturer ID (IDGV)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter lecturer ID';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: classController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Total classes (SumClass)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final number = int.tryParse(value ?? '');
                    if (number == null || number < 0) {
                      return 'Enter a valid class number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                if (previewBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      previewBytes!,
                      height: 110,
                      width: 110,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  lecturerAvatar(image, size: 110),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed:
                      (pickingImage || saving) ? null : pickImage,
                  icon: pickingImage
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.image),
                  label: Text(
                    pickingImage ? 'Loading image...' : 'Select Image',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: saving ? null : saveLecturer,
          child: saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(editing ? 'UPDATE' : 'SAVE'),
        ),
      ],
    );
  }
}
