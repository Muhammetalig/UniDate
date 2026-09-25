import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:io';
import 'package:unihub/home/home_page.dart';

class AccountInfoPage extends StatefulWidget {
  final bool isOnboarding;

  const AccountInfoPage({super.key, this.isOnboarding = false});

  @override
  State<AccountInfoPage> createState() => _AccountInfoPageState();
}

class _AccountInfoPageState extends State<AccountInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _classController = TextEditingController();
  final TextEditingController _interestTagsController = TextEditingController();
  final List <String?> _profileImageUrls = [null, null, null, null];
  final List<File?> _selectedProfileImages = [null, null, null, null];
  final ImagePicker _picker = ImagePicker();
  
  String _selectedUniversity = '';
  String _selectedDepartment = '';
  String _selectedClass = '';
  List<String> _interestTags = [];
  Map<String, String> _activeHours = {'start': '19:00', 'end': '22:00'};
  DateTime? _birthDate;
  
  String? _coverImageUrl;
  File? _selectedCoverImage;
  bool _isLoading = false;
  bool _isSaving = false;
  
  // Location variables
  LatLng? _selectedLocation;
  String _selectedAddress = '';
  bool _locationPermissionGranted = false;
  GoogleMapController? _mapController;

  List<String> _universities = [];
  List<String> _departments = [];
  List<String> _classes = [];
  


  bool _isLoadingUniversities = false;
  bool _isLoadingDepartments = false;
  bool _isLoadingClasses = false;
  final TextEditingController _searchController = TextEditingController();
  bool _hasUniSearchText = false;
  bool _hasDeptSearchText = false;
  bool _hasClassSearchText = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadUniversities();
    _loadDepartments();
    _loadClasses();
  }

  Future<void> _loadUniversities() async {
    setState(() => _isLoadingUniversities = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('universities')
          .orderBy('index')
          .get();

      final universities = snapshot.docs
          .map((doc) => doc.data()['name'] as String)
          .toList();

      universities.sort((a, b) => a.compareTo(b));

      setState(() {
        _universities = universities;
        _isLoadingUniversities = false;
      });
    } catch (e) {
      setState(() => _isLoadingUniversities = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Üniversiteler yüklenirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _loadDepartments() async {
    setState(() => _isLoadingDepartments = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('departments')
          .orderBy('index')
          .get();

      final departments = snapshot.docs
          .map((doc) => doc.data()['name'] as String)
          .toList();

      departments.sort((a, b) => a.compareTo(b));

      setState(() {
        _departments = departments;
        _isLoadingDepartments = false;
      });
    } catch (e) {
      setState(() => _isLoadingDepartments = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bölümler yüklenirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _loadClasses() async {
    setState(() => _isLoadingClasses = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('classes')
          .orderBy('index')
          .get();

      final classes = snapshot.docs
          .map((doc) => doc.data()['name'] as String)
          .toList();  

      classes.sort((a, b) => a.compareTo(b));

      setState(() {
        _classes = classes;
        _isLoadingClasses = false;
      });
    } catch (e) {
      setState(() => _isLoadingClasses = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sınıflar yüklenirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          _firstNameController.text = data['firstName'] ?? '';
          _lastNameController.text = data['lastName'] ?? '';
          
          if (data['birthDate'] != null) {
            try {
              if (data['birthDate'] is Timestamp) {
                _birthDate = (data['birthDate'] as Timestamp).toDate();
              } else if (data['birthDate'] is String) {
                _birthDate = DateTime.parse(data['birthDate']);
              }
            } catch (e) {
              debugPrint('AccountInfo: Error parsing birthDate: $e');
            }
          }
          
          _selectedUniversity = data['university'] ?? '';
          _selectedDepartment = data['department'] ?? '';
          _selectedClass = data['class'] ?? '';
          _departmentController.text = _selectedDepartment;
          _classController.text = _selectedClass;
          _bioController.text = data['bio'] ?? '';
          _interestTags = List<String>.from(data['interestTags'] ?? []);
          _activeHours = Map<String, String>.from(data['activeHours'] ?? {'start': '19:00', 'end': '22:00'});
          
          if (data['profileImages'] != null && data['profileImages'] is List) {
            final images = List<String>.from(data['profileImages']);
            for (int i = 0; i < images.length && i < 4; i++) {
              _profileImageUrls[i] = images[i];
            }
          } else if (data['profileImageUrl'] != null) {
            _profileImageUrls[0] = data['profileImageUrl'];
          }
          
          _coverImageUrl = data['coverImageUrl'];
          _interestTagsController.text = _interestTags.join(', ');
          
          // Load location data
          if (data['location'] != null && data['location'] is Map) {
            final locationData = data['location'] as Map;
            if (locationData['latitude'] != null && locationData['longitude'] != null) {
              _selectedLocation = LatLng(
                locationData['latitude'] as double,
                locationData['longitude'] as double,
              );
              _selectedAddress = locationData['address'] ?? '';
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Veri yüklenirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }



  void _showUniversityBottomSheet() {
    _searchController.clear();
    List<String> localFilteredUniversities = List.from(_universities);
    
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Text(
                      'Üniversite Seçin',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const FaIcon(FontAwesomeIcons.xmark),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  onChanged: (query) {
                    setModalState(() {
                      _hasUniSearchText = query.isNotEmpty;
                      localFilteredUniversities = query.isEmpty
                          ? List.from(_universities)
                          : _universities.where((university) => university.toLowerCase().contains(query.toLowerCase())).toList();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Üniversite ara...',
                    hintStyle: TextStyle(
                      color: theme.brightness == Brightness.dark ? Colors.grey[600] : const Color(0xFF9CA3AF),
                    ),
                    prefixIcon: const FaIcon(FontAwesomeIcons.magnifyingGlass, size: 18),
                    suffixIcon: _hasUniSearchText
                        ? IconButton(
                            icon: const FaIcon(FontAwesomeIcons.xmark, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setModalState(() {
                                _hasUniSearchText = false;
                                localFilteredUniversities = List.from(_universities);
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: theme.brightness == Brightness.dark ? const Color(0xFF2D2D2D) : Colors.grey[300]!,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF2563EB)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              Expanded(
                child: _isLoadingUniversities
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                        ),
                      )
                    : localFilteredUniversities.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FaIcon(
                                  FontAwesomeIcons.magnifyingGlass,
                                  size: 64,
                                  color: theme.brightness == Brightness.dark ? Colors.grey[600] : Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Üniversite bulunamadı',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: theme.brightness == Brightness.dark ? Colors.grey[400] : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: localFilteredUniversities.length,
                            itemBuilder: (context, index) {
                              final university = localFilteredUniversities[index];
                              final isSelected = university == _selectedUniversity;
                          
                              return ListTile(
                                title: Text(
                                  university,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    color: isSelected ? const Color(0xFF2563EB) : theme.textTheme.bodyLarge?.color,
                                  ),
                                ),
                                trailing: isSelected
                                    ? const FaIcon(FontAwesomeIcons.check, color: Color(0xFF2563EB))
                                    : null,
                                onTap: () {
                                  setState(() => _selectedUniversity = university);
                                  _searchController.clear();
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDepartmentBottomSheet() {
    _searchController.clear();
    List<String> localFilteredDepartments = List.from(_departments);
    
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Text(
                      'Bölüm Seçin',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const FaIcon(FontAwesomeIcons.xmark),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  onChanged: (query) {
                    setModalState(() {
                      _hasDeptSearchText = query.isNotEmpty;
                      localFilteredDepartments = query.isEmpty
                          ? List.from(_departments)
                          : _departments.where((department) => department.toLowerCase().contains(query.toLowerCase())).toList();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Bölüm ara...',
                    hintStyle: TextStyle(
                      color: theme.brightness == Brightness.dark ? Colors.grey[600] : const Color(0xFF9CA3AF),
                    ),
                    prefixIcon: const FaIcon(FontAwesomeIcons.magnifyingGlass, size: 18),
                    suffixIcon: _hasDeptSearchText
                        ? IconButton(
                            icon: const FaIcon(FontAwesomeIcons.xmark, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setModalState(() {
                                _hasDeptSearchText = false;
                                localFilteredDepartments = List.from(_departments);
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: theme.brightness == Brightness.dark ? const Color(0xFF2D2D2D) : Colors.grey[300]!,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF2563EB)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              Expanded(
                child: _isLoadingDepartments
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                        ),
                      )
                    : localFilteredDepartments.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FaIcon(
                                  FontAwesomeIcons.magnifyingGlass,
                                  size: 64,
                                  color: theme.brightness == Brightness.dark ? Colors.grey[600] : Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Bölüm bulunamadı',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: theme.brightness == Brightness.dark ? Colors.grey[400] : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: localFilteredDepartments.length,
                            itemBuilder: (context, index) {
                              final department = localFilteredDepartments[index];
                              final isSelected = department == _selectedDepartment;
                          
                              return ListTile(
                                title: Text(
                                  department,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    color: isSelected ? const Color(0xFF2563EB) : theme.textTheme.bodyLarge?.color,
                                  ),
                                ),
                                trailing: isSelected
                                    ? const FaIcon(FontAwesomeIcons.check, color: Color(0xFF2563EB))
                                    : null,
                                onTap: () {
                                  setState(() => _selectedDepartment = department);
                                  _searchController.clear();
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClassBottomSheet() {
    _searchController.clear();
    List<String> localFilteredClasses = List.from(_classes);
    
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Text(
                      'Sınıf Seçin',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const FaIcon(FontAwesomeIcons.xmark),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  onChanged: (query) {
                    setModalState(() {
                      _hasClassSearchText = query.isNotEmpty;
                      localFilteredClasses = query.isEmpty
                          ? List.from(_classes)
                          : _classes.where((c) => c.toLowerCase().contains(query.toLowerCase())).toList();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Sınıf ara...',
                    hintStyle: TextStyle(
                      color: theme.brightness == Brightness.dark ? Colors.grey[600] : const Color(0xFF9CA3AF),
                    ),
                    prefixIcon: const FaIcon(FontAwesomeIcons.magnifyingGlass, size: 18),
                    suffixIcon: _hasClassSearchText
                        ? IconButton(
                            icon: const FaIcon(FontAwesomeIcons.xmark, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setModalState(() {
                                _hasClassSearchText = false;
                                localFilteredClasses = List.from(_classes);
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: theme.brightness == Brightness.dark ? const Color(0xFF2D2D2D) : Colors.grey[300]!,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF2563EB)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              Expanded(
                child: _isLoadingClasses
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                        ),
                      )
                    : localFilteredClasses.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FaIcon(
                                  FontAwesomeIcons.magnifyingGlass,
                                  size: 64,
                                  color: theme.brightness == Brightness.dark ? Colors.grey[600] : Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Sınıf bulunamadı',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: theme.brightness == Brightness.dark ? Colors.grey[400] : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: localFilteredClasses.length,
                            itemBuilder: (context, index) {
                              final classItem = localFilteredClasses[index];
                              final isSelected = classItem == _selectedClass;
                          
                              return ListTile(
                                title: Text(
                                  classItem,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    color: isSelected ? const Color(0xFF2563EB) : theme.textTheme.bodyLarge?.color,
                                  ),
                                ),
                                trailing: isSelected
                                    ? const FaIcon(FontAwesomeIcons.check, color: Color(0xFF2563EB))
                                    : null,
                                onTap: () {
                                  setState(() => _selectedClass = classItem);
                                  _searchController.clear();
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Location permission and retrieval functions
  Future<void> _requestLocationPermission() async {
    debugPrint('AccountInfo: Requesting location permission');
    
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Konum servisleri kapalı. Lütfen cihaz ayarlarından açın.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Konum izni reddedildi'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Konum izni kalıcı olarak reddedildi. Ayarlardan izin veriniz.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() => _locationPermissionGranted = true);
      await _getCurrentLocation();
    } catch (e) {
      debugPrint('AccountInfo: Error requesting location permission: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Konum izni alınırken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    debugPrint('AccountInfo: Getting current location');
    
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      
      final addresses = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      String address = '';
      if (addresses.isNotEmpty) {
        final place = addresses.first;
        address = '${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}'.replaceAll(RegExp(r'^,\s*|,\s*,'), ',').trim();
      }

      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _selectedAddress = address;
      });

      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: _selectedLocation!,
              zoom: 15,
            ),
          ),
        );
      }

      debugPrint('AccountInfo: Current location: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('AccountInfo: Error getting current location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Konum alınırken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateAddressFromLocation(LatLng location) async {
    try {
      final addresses = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      
      if (addresses.isNotEmpty) {
        final place = addresses.first;
        setState(() {
          _selectedAddress = '${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}'.replaceAll(RegExp(r'^,\s*|,\s*,'), ',').trim();
        });
      }
    } catch (e) {
      debugPrint('AccountInfo: Error getting address: $e');
    }
  }

  void _showLocationBottomSheet() {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Text(
                      'Konum Seçin',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const FaIcon(FontAwesomeIcons.xmark),
                    ),
                  ],
                ),
              ),
              const Divider(),
              
              // Permission info or current location button
              if (!_locationPermissionGranted)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const FaIcon(
                              FontAwesomeIcons.locationDot,
                              color: Color(0xFF2563EB),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Konumunuzu paylaşmak için izin vermeniz gerekiyor',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await _requestLocationPermission();
                            setModalState(() {});
                          },
                          icon: const FaIcon(FontAwesomeIcons.locationArrow, size: 16),
                          label: const Text('Konum İzni Ver'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
              // Map
              Expanded(
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _selectedLocation ?? const LatLng(41.0082, 28.9784), // Istanbul default
                        zoom: 11,
                      ),
                      onMapCreated: (controller) {
                        _mapController = controller;
                        if (_selectedLocation != null) {
                          controller.animateCamera(
                            CameraUpdate.newCameraPosition(
                              CameraPosition(
                                target: _selectedLocation!,
                                zoom: 15,
                              ),
                            ),
                          );
                        }
                      },
                      onTap: (LatLng location) async {
                        debugPrint('AccountInfo: Map tapped at Lat: ${location.latitude}, Lng: ${location.longitude}');
                        setModalState(() {
                          _selectedLocation = location;
                        });
                        setState(() {
                          _selectedLocation = location;
                        });
                        await _updateAddressFromLocation(location);
                        debugPrint('AccountInfo: Address updated to: $_selectedAddress');
                        setModalState(() {});
                      },
                      markers: _selectedLocation != null
                          ? {
                              Marker(
                                markerId: const MarkerId('selected_location'),
                                position: _selectedLocation!,
                                draggable: true,
                                onDragEnd: (LatLng newLocation) async {
                                  debugPrint('AccountInfo: Marker dragged to Lat: ${newLocation.latitude}, Lng: ${newLocation.longitude}');
                                  setModalState(() {
                                    _selectedLocation = newLocation;
                                  });
                                  setState(() {
                                    _selectedLocation = newLocation;
                                  });
                                  await _updateAddressFromLocation(newLocation);
                                  debugPrint('AccountInfo: Address updated to: $_selectedAddress');
                                  setModalState(() {});
                                },
                              ),
                            }
                          : {},
                      myLocationEnabled: _locationPermissionGranted,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                    ),
                    
                    // My location button
                    if (_locationPermissionGranted)
                      Positioned(
                        bottom: 100,
                        right: 16,
                        child: FloatingActionButton(
                          onPressed: () async {
                            await _getCurrentLocation();
                            setModalState(() {});
                          },
                          backgroundColor: Colors.white,
                          child: const FaIcon(
                            FontAwesomeIcons.locationCrosshairs,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Selected address display
              if (_selectedAddress.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    border: Border(
                      top: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const FaIcon(
                            FontAwesomeIcons.locationDot,
                            color: Color(0xFF2563EB),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Seçilen Konum',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedAddress,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Confirm button
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (_selectedLocation != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedLocation = null;
                              _selectedAddress = '';
                            });
                            setModalState(() {});
                          },
                          icon: const FaIcon(FontAwesomeIcons.trash, size: 16),
                          label: const Text('Konumu Kaldır'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    if (_selectedLocation != null) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _selectedLocation != null
                            ? () {
                                debugPrint('AccountInfo: Location confirmed - Lat: ${_selectedLocation!.latitude}, Lng: ${_selectedLocation!.longitude}, Address: $_selectedAddress');
                                Navigator.pop(context);
                              }
                            : null,
                        icon: const FaIcon(FontAwesomeIcons.check, size: 16),
                        label: const Text('Onayla'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildProfileImageSlot(int index, bool isDark) {
    final hasImage = _selectedProfileImages[index] != null || _profileImageUrls[index] != null;
    
    return GestureDetector(
      onTap: () => _pickProfileImage(index),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasImage 
              ? const Color(0xFF2563EB) 
              : (isDark ? const Color(0xFF404040) : const Color(0xFFE5E7EB)),
            width: hasImage ? 2 : 1,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _selectedProfileImages[index] != null
                  ? Image.file(_selectedProfileImages[index]!, fit: BoxFit.cover)
                  : _profileImageUrls[index] != null
                      ? Image.network(
                          _profileImageUrls[index]!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(index, isDark),
                        )
                      : _buildPlaceholder(index, isDark),
            ),
            
            if (hasImage)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedProfileImages[index] = null;
                      _profileImageUrls[index] = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const FaIcon(FontAwesomeIcons.trash, color: Colors.white, size: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(int index, bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF2D2D2D) : Colors.grey[100],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(
            FontAwesomeIcons.image,
            size: 32,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            'Fotoğraf ${index + 1}',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[600] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickProfileImage(int index) async {
    try {
      debugPrint('AccountInfo: Picking profile image for index $index');
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _selectedProfileImages[index] = File(image.path);
        });
      }
    } catch (e) {
      debugPrint('AccountInfo: Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fotoğraf seçilirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickCoverImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedCoverImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kapak fotoğrafı seçilirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadImages() async {
    debugPrint('AccountInfo: Starting image upload');
    
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'];
    final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET']; 

    if (cloudName == null || uploadPreset == null || cloudName.isEmpty || uploadPreset.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cloudinary yapılandırılmadı. .env dosyasını kontrol edin.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final cloudinary = CloudinaryPublic(cloudName, uploadPreset, cache: false);

      for (int i = 0; i < _selectedProfileImages.length; i++) {
        if (_selectedProfileImages[i] != null) {
          debugPrint('AccountInfo: Uploading profile image $i');
          final res = await cloudinary.uploadFile(
            CloudinaryFile.fromFile(_selectedProfileImages[i]!.path, resourceType: CloudinaryResourceType.Image),
          );
          _profileImageUrls[i] = res.secureUrl;
          debugPrint('AccountInfo: Profile image $i uploaded: ${res.secureUrl}');
        }
      }

      if (_selectedCoverImage != null) {
        debugPrint('AccountInfo: Uploading cover image');
        final resCover = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(_selectedCoverImage!.path, resourceType: CloudinaryResourceType.Image),
        );
        _coverImageUrl = resCover.secureUrl;
        debugPrint('AccountInfo: Cover image uploaded');
      }
    } on CloudinaryException catch (err) {
      debugPrint('AccountInfo: Cloudinary error: ${err.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cloudinary hatası: ${err.message} (${err.request})'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fotoğraf yüklenirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedUniversity.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen üniversitenizi seçiniz'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _uploadImages();

        final profileImagesList = _profileImageUrls.where((url) => url != null).toList();
        
        debugPrint('AccountInfo: Saving profile with ${profileImagesList.length} images');

        Map<String, dynamic>? locationData;
        if (_selectedLocation != null) {
          locationData = {
            'latitude': _selectedLocation!.latitude,
            'longitude': _selectedLocation!.longitude,
            'address': _selectedAddress,
          };
          debugPrint('AccountInfo: Location data to save: $locationData');
        } else {
          debugPrint('AccountInfo: No location data to save (_selectedLocation is null)');
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'birthDate': _birthDate != null ? Timestamp.fromDate(_birthDate!) : null,
          'university': _selectedUniversity,
          'department': _selectedDepartment,
          'class': _selectedClass,
          'bio': _bioController.text.trim(),
          'interestTags': _interestTags,
          'activeHours': _activeHours,
          'email': user.email,
          'profileImages': profileImagesList,
          'coverImageUrl': _coverImageUrl,
          'location': locationData,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint('AccountInfo: Profile saved successfully with location: $locationData');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profil bilgileri başarıyla güncellendi'),
              backgroundColor: Colors.green,
            ),
          );
          if (widget.isOnboarding) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute<void>(builder: (_) => const HomePage()),
            );
          } else {
            Navigator.pop(context);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profil güncellenirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _bioController.dispose();
    _departmentController.dispose();
    _classController.dispose();
    _interestTagsController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.isOnboarding ? 'Profilini Tamamla' : 'Hesap Bilgileri'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
        automaticallyImplyLeading: true,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover Image Section
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              GestureDetector(
                                onTap: _pickCoverImage,
                                child: Container(
                                  width: double.infinity,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: _selectedCoverImage != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(15),
                                          child: Image.file(
                                            _selectedCoverImage!,
                                            width: double.infinity,
                                            height: 200,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : (_coverImageUrl != null
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(15),
                                              child: Image.network(
                                                _coverImageUrl!,
                                                width: double.infinity,
                                                height: 200,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) => 
                                                  Container(
                                                    color: const Color(0xFF2563EB),
                                                    child: const Center(
                                                      child: FaIcon(
                                                        FontAwesomeIcons.image,
                                                        size: 50,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                              ),
                                            )
                                          : Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    const Color(0xFF2563EB),
                                                    const Color(0xFF1D4ED8),
                                                  ],
                                                ),
                                                borderRadius: BorderRadius.circular(15),
                                              ),
                                              child: const Center(
                                                child: FaIcon(
                                                  FontAwesomeIcons.image,
                                                  size: 50,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            )),
                                ),
                              ),
                              if (_selectedCoverImage == null && _coverImageUrl == null)
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const FaIcon(
                                      FontAwesomeIcons.camera,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          // Cover photo buttons
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _pickCoverImage,
                                        icon: const FaIcon(FontAwesomeIcons.camera, size: 16),
                                        label: const Text('Kapak Değiştir'),
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2563EB),
                                          foregroundColor: Colors.white,
                                          side: const BorderSide(color: Color(0xFF2563EB)),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      ),
                                    ),
                                    if (_selectedCoverImage != null || _coverImageUrl != null) ...[
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () async {
                                            setState(() {
                                              _selectedCoverImage = null;
                                              _coverImageUrl = null;
                                            });
                                            final user = FirebaseAuth.instance.currentUser;
                                            if (user != null) {
                                              await FirebaseFirestore.instance
                                                  .collection('users')
                                                  .doc(user.uid)
                                                  .update({'coverImageUrl': null});
                                            }
                                          },
                                          icon: const FaIcon(FontAwesomeIcons.trash, size: 16),
                                          label: const Text('Kapak Kaldır'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.red,
                                            side: const BorderSide(color: Colors.red),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 20),
                                
                                // Profile Photos Grid
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const FaIcon(FontAwesomeIcons.images, color: Color(0xFF2563EB), size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Profil Fotoğrafları',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: theme.textTheme.bodyLarge?.color,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Maksimum 4 fotoğraf ekleyebilirsiniz',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      GridView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 12,
                                          childAspectRatio: 1,
                                        ),
                                        itemCount: 4,
                                        itemBuilder: (context, index) => _buildProfileImageSlot(index, isDark),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Form fields
                    _buildFormField(
                      context: context,
                      controller: _firstNameController,
                      label: 'Ad',
                      hint: 'Adınızı giriniz',
                      icon: FontAwesomeIcons.user,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ad alanı zorunludur';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    _buildFormField(
                      context: context,
                      controller: _lastNameController,
                      label: 'Soyad',
                      hint: 'Soyadınızı giriniz',
                      icon: FontAwesomeIcons.user,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Soyad alanı zorunludur';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Birth Date Picker
                    InkWell(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _birthDate ?? DateTime(2000, 1, 1),
                          firstDate: DateTime(1940),
                          lastDate: DateTime.now(),
                          locale: const Locale('tr', 'TR'),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: const Color(0xFF2563EB),
                                  onPrimary: Colors.white,
                                  surface: theme.cardColor,
                                  onSurface: theme.textTheme.bodyLarge?.color ?? Colors.black,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null && mounted) {
                          setState(() => _birthDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE5E7EB),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: theme.cardColor,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Center(
                                child: FaIcon(
                                  FontAwesomeIcons.cakeCandles,
                                  color: Color(0xFF2563EB),
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Doğum Tarihi',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _birthDate != null
                                        ? '${_birthDate!.day.toString().padLeft(2, '0')}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year}'
                                        : 'Doğum tarihinizi seçin',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: _birthDate != null
                                          ? (isDark ? Colors.white : Colors.black87)
                                          : Colors.grey[500],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const FaIcon(
                              FontAwesomeIcons.calendar,
                              color: Color(0xFF2563EB),
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // University selection
                    _buildSectionTitle('Üniversite', theme),
                    const SizedBox(height: 8),
                    _buildSelectionField(
                      icon: FontAwesomeIcons.graduationCap,
                      text: _selectedUniversity.isEmpty ? 'Üniversitenizi seçiniz' : _selectedUniversity,
                      isEmpty: _selectedUniversity.isEmpty,
                      onTap: _showUniversityBottomSheet,
                      theme: theme,
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Department selection
                    _buildSectionTitle('Bölüm', theme),
                    const SizedBox(height: 8),
                    _buildSelectionField(
                      icon: FontAwesomeIcons.book,
                      text: _selectedDepartment.isEmpty ? 'Bölümünüzü seçiniz' : _selectedDepartment,
                      isEmpty: _selectedDepartment.isEmpty,
                      onTap: _showDepartmentBottomSheet,
                      theme: theme,
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Class selection
                    _buildSectionTitle('Sınıf', theme),
                    const SizedBox(height: 8),
                    _buildSelectionField(
                      icon: FontAwesomeIcons.award,
                      text: _selectedClass.isEmpty ? 'Sınıfınızı seçiniz' : _selectedClass,
                      isEmpty: _selectedClass.isEmpty,
                      onTap: _showClassBottomSheet,
                      theme: theme,
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Bio field
                    _buildSectionTitle('Kısa Bio', theme),
                    const SizedBox(height: 8),
                    _buildFormField(
                      context: context,
                      controller: _bioController,
                      label: '',
                      hint: 'Kendinizi kısaca tanıtın (140-200 karakter)',
                      icon: FontAwesomeIcons.penToSquare,
                      maxLines: 3,
                      maxLength: 200,
                      validator: (value) {
                        if (value != null && value.length > 200) {
                          return 'Bio 200 karakterden uzun olamaz';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Interest Tags
                    _buildSectionTitle('İlgi Alanları', theme),
                    const SizedBox(height: 8),
                    _buildFormField(
                      context: context,
                      controller: _interestTagsController,
                      label: '',
                      hint: 'İlgi alanlarınızı virgülle ayırın (örn: koşu, sinema, müzik)',
                      icon: FontAwesomeIcons.tag,
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          _interestTags = value.split(',').map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList();
                        } else {
                          _interestTags = [];
                        }
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Active Hours
                    _buildSectionTitle('Aktif Zamanlar', theme),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTimeSelector('Başlangıç', _activeHours['start']!, (time) {
                            setState(() => _activeHours['start'] = time);
                          }),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildTimeSelector('Bitiş', _activeHours['end']!, (time) {
                            setState(() => _activeHours['end'] = time);
                          }),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Location Section
                    _buildSectionTitle('Konum', theme),
                    const SizedBox(height: 8),
                    _buildSelectionField(
                      icon: FontAwesomeIcons.locationDot,
                      text: _selectedLocation != null 
                          ? (_selectedAddress.isNotEmpty ? _selectedAddress : 'Konum seçildi')
                          : 'Konumunuzu seçiniz (İsteğe bağlı)',
                      isEmpty: _selectedLocation == null,
                      onTap: _showLocationBottomSheet,
                      theme: theme,
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Hesap Bilgilerini Kaydet',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: theme.textTheme.bodyLarge?.color,
      ),
    );
  }

  Widget _buildSelectionField({
    required IconData icon,
    required String text,
    required bool isEmpty,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE5E7EB),
          ),
          borderRadius: BorderRadius.circular(12),
          color: theme.cardColor,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            FaIcon(
              icon,
              color: isDark ? Colors.grey[600] : const Color(0xFF9CA3AF),
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: isEmpty 
                      ? (isDark ? Colors.grey[600] : const Color(0xFF9CA3AF))
                      : theme.textTheme.bodyLarge?.color,
                  fontSize: 15,
                ),
              ),
            ),
            FaIcon(
              FontAwesomeIcons.chevronDown,
              color: isDark ? Colors.grey[600] : const Color(0xFF9CA3AF),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
    int maxLines = 1,
    int? maxLength,
    void Function(String)? onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      maxLines: maxLines,
      maxLength: maxLength,
      onChanged: onChanged,
      style: TextStyle(
        fontSize: 15,
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label.isNotEmpty ? label : null,
        hintText: hint,
        labelStyle: TextStyle(
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        hintStyle: TextStyle(
          color: isDark ? Colors.grey[600] : Colors.grey[400],
          fontSize: 14,
        ),
        prefixIcon: maxLines > 1
            ? Padding(
                padding: const EdgeInsets.only(top: 12, left: 12, right: 8),
                child: FaIcon(
                  icon,
                  size: 18,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              )
            : Center(
                widthFactor: 1.0,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: FaIcon(
                    icon,
                    size: 18,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
              ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: maxLines > 1 ? 14 : 16,
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF1F1F1F) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE5E7EB),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE5E7EB),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        counterStyle: TextStyle(
          color: isDark ? Colors.grey[500] : Colors.grey[600],
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTimeSelector(String label, String time, Function(String) onTimeChanged) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () async {
        final TimeOfDay? picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(DateTime.parse('2023-01-01 $time:00')),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: const Color(0xFF2563EB),
                  onPrimary: Colors.white,
                  surface: theme.cardColor,
                  onSurface: theme.textTheme.bodyLarge?.color ?? Colors.black,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          final formattedTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
          onTimeChanged(formattedTime);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE5E7EB),
          ),
          borderRadius: BorderRadius.circular(12),
          color: theme.cardColor,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[400] : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.clock,
                  color: isDark ? Colors.grey[600] : const Color(0xFF9CA3AF),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
