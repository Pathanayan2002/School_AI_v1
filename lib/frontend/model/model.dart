import 'dart:convert';

class User {
  final String id;
  final String name;
  final String enrollmentId;
  final String email;
  final String phone;
  final String role;
  final List<String>? subjects; // List of subject IDs
  final String? schoolId;

  User({
    required this.id,
    required this.name,
    required this.enrollmentId,
    required this.email,
    required this.phone,
    required this.role,
    this.subjects,
    this.schoolId,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id']?.toString() ?? '',
      name: json['name'] ?? '',
      enrollmentId: json['enrollmentId']?.toString() ?? '',
      email: json['email'] ?? '',
      phone: json['phone']?.toString() ?? '',
      role: json['role'] ?? '',
      subjects: json['subjects'] != null ? List<String>.from(json['subjects'].map((s) => s.toString())) : null,
      schoolId: json['schoolId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'enrollmentId': enrollmentId,
      'email': email,
      'phone': phone,
      'role': role,
      if (subjects != null) 'subjects': subjects,
      if (schoolId != null) 'schoolId': schoolId,
    };
  }
}

class Student {
  final String id;
  final String name;
  final String rollNo;
  final String parentsPhno;
  final String? caste;
  final String? subCaste;
  final String? sex;
  final String? aparId;
  final String? saralId;
  final String? mobileNumber;
  final String? dob;
  final String? admissionDate;
  final String? address;
  final String? motherTongue;
  final String? previousSchool;
  final Map<String, Map<String, dynamic>>? marks;
  final String? classId;
  final String? division;
  final String? registerNumber;
  final String? motherName;
  final String? adharNumber;
  final String? bankPassbook;
  final String? photo;

  Student({
    required this.id,
    required this.name,
    required this.rollNo,
    required this.parentsPhno,
    this.caste,
    this.subCaste,
    this.sex,
    this.aparId,
    this.saralId,
    this.mobileNumber,
    this.dob,
    this.admissionDate,
    this.address,
    this.motherTongue,
    this.previousSchool,
    this.marks,
    this.classId,
    this.division,
    this.registerNumber,
    this.motherName,
    this.adharNumber,
    this.bankPassbook,
    this.photo,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['_id']?.toString() ?? '',
      name: json['name'] ?? '',
      rollNo: json['rollNo']?.toString() ?? '',
      parentsPhno: json['parentsPhno']?.toString() ?? '',
      caste: json['caste']?.toString(),
      subCaste: json['subCaste']?.toString(),
      sex: json['sex']?.toString(),
      aparId: json['aparId']?.toString(),
      saralId: json['saralId']?.toString(),
      mobileNumber: json['mobileNumber']?.toString(),
      dob: json['dob']?.toString(),
      admissionDate: json['admissionDate']?.toString(),
      address: json['address']?.toString(),
      motherTongue: json['motherToung'] ?? json['motherTongue']?.toString(),
      previousSchool: json['previousSchool']?.toString(),
      marks: json['marks'] != null
          ? (json['marks'] as Map<String, dynamic>).map(
              (key, value) => MapEntry(
                key,
                Map<String, dynamic>.from(value),
              ),
            )
          : null,
      classId: json['classId']?.toString(),
      division: json['division']?.toString(),
      registerNumber: json['registerNumber']?.toString(),
      motherName: json['motherName']?.toString(),
      adharNumber: json['adharNumber']?.toString(),
      bankPassbook: json['bankPassbook']?.toString(),
      photo: json['photo']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'rollNo': rollNo,
      'parentsPhno': parentsPhno,
      if (caste != null) 'caste': caste,
      if (subCaste != null) 'subCaste': subCaste,
      if (sex != null) 'sex': sex,
      if (aparId != null) 'aparId': aparId,
      if (saralId != null) 'saralId': saralId,
      if (mobileNumber != null) 'mobileNumber': mobileNumber,
      if (dob != null) 'dob': dob,
      if (admissionDate != null) 'admissionDate': admissionDate,
      if (address != null) 'address': address,
      if (motherTongue != null) 'motherTongue': motherTongue,
      if (previousSchool != null) 'previousSchool': previousSchool,
      if (marks != null) 'marks': marks,
      if (classId != null) 'classId': classId,
      if (division != null) 'division': division,
      if (registerNumber != null) 'registerNumber': registerNumber,
      if (motherName != null) 'motherName': motherName,
      if (adharNumber != null) 'adharNumber': adharNumber,
      if (bankPassbook != null) 'bankPassbook': bankPassbook,
      if (photo != null) 'photo': photo,
    };
  }
}

class ClassModel {
  final String id;
  final String name;
  final String? standard;
  final String? division;
  final String? teacherId;
  final String? schoolId;
  final List<dynamic>? students;
  final Map<String, dynamic>? classTeachers;

  ClassModel({
    required this.id,
    required this.name,
    this.standard,
    this.division,
    this.teacherId,
    this.schoolId,
    this.students,
    this.classTeachers,
  });

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: json['_id']?.toString() ?? '',
      name: json['name'] ?? '',
      standard: json['standard']?.toString(),
      division: json['divsion'] ?? json['division']?.toString(),
      teacherId: json['teacherId']?.toString(),
      schoolId: json['schoolId']?.toString(),
      students: json['students'],
      classTeachers: json['ClassTeachers'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      if (standard != null) 'standard': standard,
      if (division != null) 'division': division,
      if (teacherId != null) 'teacherId': teacherId,
      if (schoolId != null) 'schoolId': schoolId,
      if (students != null) 'students': students,
      if (classTeachers != null) 'ClassTeachers': classTeachers,
    };
  }
}

class SubjectItem {
  final String id;
  final String name;
  final String? standard;
  final String? classId;

  SubjectItem({
    required this.id,
    required this.name,
    this.standard,
    this.classId,
  });

  factory SubjectItem.fromJson(Map<String, dynamic> json) {
    return SubjectItem(
      id: json['_id']?.toString() ?? '',
      name: json['name'] ?? '',
      standard: json['standard']?.toString(),
      classId: json['classId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      if (standard != null) 'standard': standard,
      if (classId != null) 'classId': classId,
    };
  }
}
