import 'package:flutter_test/flutter_test.dart';
import 'package:ajra/core/security/roles_and_permissions.dart';
import 'package:ajra/features/membership/models/member_profile.dart';

void main() {
  group('MemberProfile Model Tests', () {
    test('Correctly masks passport number for unprivileged views', () {
      final member = MemberProfile(
        id: 'user-1',
        userId: 'user-1',
        memberNumber: 'AJRA-2026-001',
        lastName: 'Ranaivo',
        firstName: 'Jean',
        birthDate: DateTime(1995, 5, 12),
        residentialAddress: 'Ebene Cybercity',
        email: 'jean.ranaivo@gmail.com',
        phone: '+23055551234',
        appliedAt: DateTime.now(),
        status: MembershipStatus.active,
        passportNumber: 'AB1234567',
        passportIssueDate: DateTime(2022, 1, 1),
        passportExpiryDate: DateTime.now().add(const Duration(days: 300)),
        permitType: PermitType.worker,
        jobTitle: 'Ingénieur',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(member.maskedPassportNumber, 'AB****67');
      expect(member.fullName, 'Jean Ranaivo');
      expect(member.isActive, isTrue);
    });

    test('Identifies expiring and expired passports', () {
      final now = DateTime.now();

      final expiringMember = MemberProfile(
        id: 'user-2',
        userId: 'user-2',
        memberNumber: 'AJRA-2026-002',
        lastName: 'Soa',
        firstName: 'Miora',
        birthDate: DateTime(1998, 3, 20),
        residentialAddress: 'Port Louis',
        email: 'miora.soa@gmail.com',
        phone: '+23055554321',
        appliedAt: now,
        status: MembershipStatus.active,
        passportNumber: 'CD9876543',
        passportIssueDate: now.subtract(const Duration(days: 365 * 4)),
        passportExpiryDate: now.add(const Duration(days: 45)), // In 45 days
        permitType: PermitType.student,
        fieldOfStudy: 'Management',
        createdAt: now,
        updatedAt: now,
      );

      expect(expiringMember.isPassportExpired, isFalse);
      expect(expiringMember.isPassportExpiringSoon(90), isTrue);
      expect(expiringMember.isPassportExpiringSoon(30), isFalse);
    });
  });
}
