
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

    return 'http://10.0.2.2:3000';
  }

  static Map<String, String> headers() {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Map<String, dynamic> decode(http.Response response) {
    return jsonDecode(response.body) as Map<String, dynamic>;
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

    final data = decode(response);

    if (response.statusCode != 200) {
      throw Exception(data['message']);
    }

    return data['token'];
  }

  static Future<List<dynamic>> getLecturers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/lecturers'),
      headers: headers(),
    );

    if (response.statusCode != 200) {
      throw Exception(decode(response)['message']);
    }

    return jsonDecode(response.body) as List<dynamic>;
  }

  static Future<void> addLecturer(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/lecturers'),
      headers: headers(),
      body: jsonEncode(data),
    );

    if (response.statusCode != 200) {
      throw Exception(decode(response)['message']);
    }
  }

  static Future<void> updateLecturer(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse(
        '$baseUrl/api/lecturers/${Uri.encodeComponent(id)}',
      ),
      headers: headers(),
      body: jsonEncode(data),
    );

    if (response.statusCode != 200) {
      throw Exception(decode(response)['message']);
    }
  }

  static Future<void> deleteLecturer(String id) async {
    final response = await http.delete(
      Uri.parse(
        '$baseUrl/api/lecturers/${Uri.encodeComponent(id)}',
      ),
      headers: headers(),
    );

    if (response.statusCode != 200) {
      throw Exception(decode(response)['message']);
    }
  }
}

// =====================================================
// IMAGE HELPER
// =====================================================

Uint8List? decodeImage(String? image) {
  if (image == null || image.isEmpty) return null;

  try {
    final base64String = image.contains(',')
        ? image.split(',').last
        : image;

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

  @override
  Widget build(BuildContext context) {
    if (loggedIn) {
      return LecturerPage(
        onLogout: () {
          Api.token = null;
          setState(() => loggedIn = false);
        },
      );
    }

    return LoginPage(
      onLogin: (value) {
        Api.token = value;
        setState(() => loggedIn = true);
      },
    );
  }
}

// =====================================================
// LOGIN PAGE
// =====================================================

class LoginPage extends StatefulWidget {
  final Function(String) onLogin;

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
      final token = await Api.login(
        emailController.text.trim(),
        passwordController.text,
      );

      widget.onLogin(token);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }

    if (mounted) setState(() => loading = false);
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
                            ? const CircularProgressIndicator()
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

  @override
  void initState() {
    super.initState();
    loadLecturers();
  }

  Future<void> loadLecturers() async {
    setState(() => loading = true);

    try {
      lecturers = await Api.getLecturers();
    } catch (e) {
      showMessage(e.toString());
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ADD / EDIT FORM

  Future<void> showLecturerForm(
    {Map<String, dynamic>? lecturer}
  ) async {
    final editing = lecturer != null;

    final idController = TextEditingController(
      text: lecturer?['IDGV'] ?? '',
    );

    final nameController = TextEditingController(
      text: lecturer?['Fullname'] ?? '',
    );

    final classController = TextEditingController(
      text: lecturer?['SumClass']?.toString() ?? '',
    );

    String image = lecturer?['Image'] ?? '';
    XFile? selectedImage;
    Uint8List? previewBytes;

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                editing ? 'Edit Lecturer' : 'Add Lecturer',
              ),

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
                          Image.memory(
                            previewBytes!,
                            height: 110,
                            width: 110,
                            fit: BoxFit.cover,
                          )
                        else
                          lecturerAvatar(image, size: 110),

                        const SizedBox(height: 10),

                        OutlinedButton.icon(
                          onPressed: () async {
                            final file = await ImagePicker().pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 70,
                              maxWidth: 600,
                              maxHeight: 600,
                            );

                            if (file != null) {
                              final bytes = await file.readAsBytes();

                              setDialogState(() {
                                selectedImage = file;
                                previewBytes = bytes;
                              });
                            }
                          },
                          icon: const Icon(Icons.image),
                          label: const Text('Select Image'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),

                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    setDialogState(() {});

                    try {
                      String finalImage = image;

                      if (selectedImage != null) {
                        final bytes = await selectedImage!.readAsBytes();
                        final mime = selectedImage!.mimeType ?? 'image/jpeg';

                        finalImage =
                            'data:$mime;base64,${base64Encode(bytes)}';
                      }

                      if (finalImage.isEmpty) {
                        showMessage('Please select an image');
                        return;
                      }

                      final data = {
                        'IDGV': idController.text.trim(),
                        'Fullname': nameController.text.trim(),
                        'Image': finalImage,
                        'SumClass': int.parse(classController.text.trim()),
                      };

                      if (editing) {
                        await Api.updateLecturer(
                          idController.text.trim(),
                          data,
                        );
                      } else {
                        await Api.addLecturer(data);
                      }

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }

                      await loadLecturers();

                      if (mounted) {
                        showMessage(
                          editing
                              ? 'Lecturer updated successfully'
                              : 'Lecturer added successfully',
                        );
                      }
                    } catch (e) {
                      showMessage(e.toString());
                    }
                  },
                  child: Text(editing ? 'UPDATE' : 'SAVE'),
                ),
              ],
            );
          },
        );
      },
    );

    idController.dispose();
    nameController.dispose();
    classController.dispose();
  }

  // DELETE LECTURER

  Future<void> deleteLecturer(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Lecturer'),
        content: Text('Delete lecturer $id?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Api.deleteLecturer(id);
        await loadLecturers();
        showMessage('Lecturer deleted successfully');
      } catch (e) {
        showMessage(e.toString());
      }
    }
  }

  // MAIN UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lecturer Management'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: loadLecturers,
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
          : lecturers.isEmpty
              ? const Center(child: Text('No lecturers found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: lecturers.length,
                  itemBuilder: (context, index) {
                    final lecturer =
                        lecturers[index] as Map<String, dynamic>;

                    return Card(
                      child: ListTile(
                        leading: lecturerAvatar(
                          lecturer['Image'],
                          size: 55,
                        ),

                        title: Text(
                          lecturer['Fullname'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        subtitle: Text(
                          'ID: ${lecturer['IDGV']}'
                          ' | Classes: ${lecturer['SumClass']}',
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
                              onPressed: () => showLecturerForm(
                                lecturer: lecturer,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.red,
                              ),
                              onPressed: () => deleteLecturer(
                                lecturer['IDGV'],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showLecturerForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Lecturer'),
      ),
    );
  }
}
