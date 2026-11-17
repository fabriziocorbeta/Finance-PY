class LoanDetails {
  final String? rateType;
  final double? interestRate;
  final int? termMonths;
  final double? initialBalance;
  final String? amortizationMethod;

  LoanDetails({
    this.rateType,
    this.interestRate,
    this.termMonths,
    this.initialBalance,
    this.amortizationMethod,
  });

  factory LoanDetails.fromJson(Map<String, dynamic> json) {
    return LoanDetails(
      rateType: json['rate_type'] as String?,
      interestRate: (json['interest_rate'] as num?)?.toDouble(),
      termMonths: (json['term_months'] as num?)?.toInt(),
      initialBalance: (json['initial_balance'] as num?)?.toDouble(),
      amortizationMethod: json['amortization_method'] as String?,
    );
  }
}

class CreditCardDetails {
  final double? availableCredit;
  final double? minimumPayment;
  final double? apr;
  final double? annualFee;
  final String? expirationDate;

  CreditCardDetails({
    this.availableCredit,
    this.minimumPayment,
    this.apr,
    this.annualFee,
    this.expirationDate,
  });

  factory CreditCardDetails.fromJson(Map<String, dynamic> json) {
    return CreditCardDetails(
      availableCredit: (json['available_credit'] as num?)?.toDouble(),
      minimumPayment: (json['minimum_payment'] as num?)?.toDouble(),
      apr: (json['apr'] as num?)?.toDouble(),
      annualFee: (json['annual_fee'] as num?)?.toDouble(),
      expirationDate: json['expiration_date'] as String?,
    );
  }
}

class VehicleDetails {
  final String? make;
  final String? model;
  final int? year;
  final int? mileageValue;
  final String? mileageUnit;

  VehicleDetails({this.make, this.model, this.year, this.mileageValue, this.mileageUnit});

  factory VehicleDetails.fromJson(Map<String, dynamic> json) {
    return VehicleDetails(
      make: json['make'] as String?,
      model: json['model'] as String?,
      year: (json['year'] as num?)?.toInt(),
      mileageValue: (json['mileage_value'] as num?)?.toInt(),
      mileageUnit: json['mileage_unit'] as String?,
    );
  }
}

class CryptoDetails {
  final String? taxTreatment;

  CryptoDetails({this.taxTreatment});

  factory CryptoDetails.fromJson(Map<String, dynamic> json) {
    return CryptoDetails(taxTreatment: json['tax_treatment'] as String?);
  }
}

class AccountDetail {
  final String id;
  final String name;
  final String balance;
  final String cashBalance;
  final String currency;
  final String? classification;
  final String accountType;
  final String? subtype;
  final String status;
  final String? institutionName;
  final LoanDetails? loanDetails;
  final CreditCardDetails? creditCardDetails;
  final VehicleDetails? vehicleDetails;
  final CryptoDetails? cryptoDetails;

  AccountDetail({
    required this.id,
    required this.name,
    required this.balance,
    required this.cashBalance,
    required this.currency,
    this.classification,
    required this.accountType,
    this.subtype,
    required this.status,
    this.institutionName,
    this.loanDetails,
    this.creditCardDetails,
    this.vehicleDetails,
    this.cryptoDetails,
  });

  factory AccountDetail.fromJson(Map<String, dynamic> json) {
    return AccountDetail(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      balance: json['balance'] as String? ?? '0',
      cashBalance: json['cash_balance'] as String? ?? '0',
      currency: json['currency'] as String? ?? 'USD',
      classification: json['classification'] as String?,
      accountType: json['account_type'] as String? ?? '',
      subtype: json['subtype'] as String?,
      status: json['status'] as String? ?? 'active',
      institutionName: json['institution_name'] as String?,
      loanDetails: json['loan_details'] != null
          ? LoanDetails.fromJson(json['loan_details'] as Map<String, dynamic>)
          : null,
      creditCardDetails: json['credit_card_details'] != null
          ? CreditCardDetails.fromJson(json['credit_card_details'] as Map<String, dynamic>)
          : null,
      vehicleDetails: json['vehicle_details'] != null
          ? VehicleDetails.fromJson(json['vehicle_details'] as Map<String, dynamic>)
          : null,
      cryptoDetails: json['crypto_details'] != null
          ? CryptoDetails.fromJson(json['crypto_details'] as Map<String, dynamic>)
          : null,
    );
  }
}
