import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/student_service.dart';

class ManageStudentsScreen extends StatefulWidget {
  const ManageStudentsScreen({super.key});

  @override
  State<ManageStudentsScreen> createState() => _ManageStudentsScreenState();
}

class _ManageStudentsScreenState extends State<ManageStudentsScreen> {
  final StudentService _studentService = StudentService();
  String _searchQuery = '';
  String _filterSchool = 'all';
  String _filterParent = 'all';

  List<Map<String, dynamic>> _schools = [];
  List<Map<String, dynamic>> _parents = [];

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  Future<void> _loadFilters() async {
    final schools = await _studentService.getAllSchools();
    final parents = await _studentService.getAllParents();
    if (mounted) {
      setState(() {
        _schools = schools;
        _parents = parents;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Students'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(child: _buildStudentsList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStudentDialog(),
        backgroundColor: Colors.deepPurple,
        icon: const Icon(Icons.add),
        label: const Text('Add Student'),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search students...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _filterSchool,
                  decoration: InputDecoration(
                    labelText: 'Filter by School',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('All Schools'),
                    ),
                    ..._schools.map(
                      (school) => DropdownMenuItem(
                        value: school['id'],
                        child: Text(school['name']),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _filterSchool = value ?? 'all'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _filterParent,
                  decoration: InputDecoration(
                    labelText: 'Filter by Parent',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('All Parents'),
                    ),
                    ..._parents.map(
                      (parent) => DropdownMenuItem(
                        value: parent['id'],
                        child: Text(parent['name']),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _filterParent = value ?? 'all'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _studentService.getAllChildrenAsStudents(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: \\${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var students = snapshot.data!;

        // Apply filters
        if (_searchQuery.isNotEmpty) {
          students = students.where((s) {
            final name = (s['name'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery.toLowerCase());
          }).toList();
        }
        if (_filterSchool != 'all') {
          students = students.where((s) {
            return s['school_name'] ==
                _schools.firstWhere(
                  (sch) => sch['id'] == _filterSchool,
                  orElse: () => {},
                )['name'];
          }).toList();
        }
        if (_filterParent != 'all') {
          students = students.where((s) {
            return s['parent_id'] == _filterParent;
          }).toList();
        }
        if (students.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No students found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: students.length,
          itemBuilder: (context, index) {
            final student = students[index];
            return _StudentCard(
              student: student,
              onEdit: () => _showStudentDialog(student: student),
              onDelete: () => _confirmDelete(student),
            );
          },
        );
      },
    );
  }

  void _showStudentDialog({Map<String, dynamic>? student}) {
    showDialog(
      context: context,
      builder: (context) =>
          _StudentDialog(student: student, studentService: _studentService),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> student) async {
    // Only allow delete for students from the main students collection (not children subcollections)
    if (student['from_children'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete students from children subcollections.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text(
          'Are you sure you want to delete ${student['name']}?\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _studentService.deleteStudent(student['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Student deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

class _StudentCard extends StatelessWidget {
  final Map<String, dynamic> student;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StudentCard({
    required this.student,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.deepPurple.shade100,
                  child: Text(
                    student['name'][0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.deepPurple.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student['name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (student['grade'] != null)
                        Text(
                          'Grade ${student['grade']}${student['section'] != null ? ' - ${student['section']}' : ''}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('parents')
                  .doc(student['parent_id'])
                  .get(),
              builder: (context, parentSnapshot) {
                if (!parentSnapshot.hasData) return const SizedBox.shrink();
                final parentData =
                    parentSnapshot.data!.data() as Map<String, dynamic>?;
                return _infoRow(
                  Icons.person,
                  'Parent',
                  parentData?['name'] ?? 'Unknown',
                );
              },
            ),
            _infoRow(
              Icons.school,
              'School',
              student['school_name'] ?? 'Unknown',
            ),
            if (student['assigned_driver_id'] != null)
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('drivers')
                    .doc(student['assigned_driver_id'])
                    .get(),
                builder: (context, driverSnapshot) {
                  if (!driverSnapshot.hasData) return const SizedBox.shrink();
                  final driverData =
                      driverSnapshot.data!.data() as Map<String, dynamic>?;
                  return _infoRow(
                    Icons.drive_eta,
                    'Driver',
                    driverData?['name'] ?? 'Unknown',
                  );
                },
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepPurple,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey[800])),
          ),
        ],
      ),
    );
  }
}

class _StudentDialog extends StatefulWidget {
  final Map<String, dynamic>? student;
  final StudentService studentService;

  const _StudentDialog({this.student, required this.studentService});

  @override
  State<_StudentDialog> createState() => _StudentDialogState();
}

class _StudentDialogState extends State<_StudentDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _gradeController;
  late TextEditingController _sectionController;

  String? _selectedParentId;
  String? _selectedSchoolId;
  String? _selectedDriverId;

  List<Map<String, dynamic>> _parents = [];
  List<Map<String, dynamic>> _schools = [];
  List<Map<String, dynamic>> _drivers = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.student?['name'] ?? '',
    );
    _gradeController = TextEditingController(
      text: widget.student?['grade'] ?? '',
    );
    _sectionController = TextEditingController(
      text: widget.student?['section'] ?? '',
    );

    _selectedParentId = widget.student?['parent_id'];
    _selectedSchoolId = widget.student?['school_id'];
    _selectedDriverId = widget.student?['assigned_driver_id'];

    _loadData();
  }

  Future<void> _loadData() async {
    final parents = await widget.studentService.getAllParents();
    final schools = await widget.studentService.getAllSchools();
    final drivers = await widget.studentService.getAvailableDrivers();

    if (mounted) {
      setState(() {
        _parents = parents;
        _schools = schools;
        _drivers = drivers;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gradeController.dispose();
    _sectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFromChildren =
        widget.student != null && widget.student!['from_children'] == true;
    return AlertDialog(
      title: Text(widget.student == null ? 'Add Student' : 'Edit Student'),
      content: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Student Name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter student name';
                        }
                        return null;
                      },
                      enabled:
                          widget.student ==
                          null, // Disable editing for children
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedParentId,
                      decoration: const InputDecoration(
                        labelText: 'Parent *',
                        border: OutlineInputBorder(),
                      ),
                      items: _parents.map((parent) {
                        return DropdownMenuItem<String>(
                          value: parent['id'] as String,
                          child: Text('${parent['name']} (${parent['email']})'),
                        );
                      }).toList(),
                      onChanged: widget.student == null
                          ? (value) => setState(() => _selectedParentId = value)
                          : null,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a parent';
                        }
                        return null;
                      },
                      // Disable for children
                      disabledHint: widget.student != null
                          ? Text(
                              _parents.firstWhere(
                                    (p) => p['id'] == _selectedParentId,
                                    orElse: () => {
                                      'name': 'Unknown',
                                      'email': '',
                                    },
                                  )['name'] ??
                                  'Unknown',
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedSchoolId,
                      decoration: const InputDecoration(
                        labelText: 'School *',
                        border: OutlineInputBorder(),
                      ),
                      items: _schools.map((school) {
                        return DropdownMenuItem<String>(
                          value: school['id'] as String,
                          child: Text('${school['name']} (${school['type']})'),
                        );
                      }).toList(),
                      onChanged: widget.student == null
                          ? (value) => setState(() => _selectedSchoolId = value)
                          : null,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a school';
                        }
                        return null;
                      },
                      disabledHint: widget.student != null
                          ? Text(
                              _schools.firstWhere(
                                    (s) => s['id'] == _selectedSchoolId,
                                    orElse: () => {
                                      'name': 'Unknown',
                                      'type': '',
                                    },
                                  )['name'] ??
                                  'Unknown',
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _gradeController,
                      decoration: const InputDecoration(
                        labelText: 'Grade',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., 1, 2, 3...',
                      ),
                      enabled: widget.student == null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _sectionController,
                      decoration: const InputDecoration(
                        labelText: 'Section',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., A, B, C...',
                      ),
                      enabled: widget.student == null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedDriverId,
                      decoration: const InputDecoration(
                        labelText: 'Assigned Driver (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('No driver assigned'),
                        ),
                        ..._drivers.map((driver) {
                          return DropdownMenuItem(
                            value: driver['id'],
                            child: Text(
                              '${driver['name']} - ${driver['assigned_bus_id']}',
                            ),
                          );
                        }),
                      ],
                      onChanged: widget.student == null
                          ? (value) => setState(() => _selectedDriverId = value)
                          : null,
                      disabledHint:
                          widget.student != null && _selectedDriverId != null
                          ? Text(
                              _drivers.firstWhere(
                                    (d) => d['id'] == _selectedDriverId,
                                    orElse: () => {
                                      'name': 'Unknown',
                                      'assigned_bus_id': '',
                                    },
                                  )['name'] ??
                                  'Unknown',
                            )
                          : null,
                    ),
                    if (isFromChildren)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          'Editing is disabled for students from children subcollections.',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading || isFromChildren ? null : _saveStudent,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      // Only allow add if student is null
      if (widget.student == null) {
        await widget.studentService.addStudent(
          name: _nameController.text.trim(),
          parentId: _selectedParentId!,
          schoolId: _selectedSchoolId!,
          driverId: _selectedDriverId,
          grade: _gradeController.text.trim().isEmpty
              ? null
              : _gradeController.text.trim(),
          section: _sectionController.text.trim().isEmpty
              ? null
              : _sectionController.text.trim(),
        );
      } else {
        // Editing is disabled for students from children subcollections (UI disables Save button)
        return;
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.student == null
                  ? 'Student added successfully'
                  : 'Student updated successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
