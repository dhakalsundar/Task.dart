// Banking System OOP Challenge — Dart

//  Domain Exceptions 
class BankingException implements Exception {
  final String message;
  BankingException(this.message);
  @override
  String toString() => 'BankingException: $message';
}

class InvalidAmountException extends BankingException {
  InvalidAmountException(String msg) : super(msg);
}

class AccountNotFoundException extends BankingException {
  AccountNotFoundException(int number) : super('Account #$number not found.');
}

class WithdrawalLimitExceededException extends BankingException {
  WithdrawalLimitExceededException(String msg) : super(msg);
}

class MinimumBalanceException extends BankingException {
  MinimumBalanceException(String msg) : super(msg);
}

class InsufficientFundsException extends BankingException {
  InsufficientFundsException(String msg) : super(msg);
}

//  Abstraction & Encapsulation 
abstract class BankAccount {
  int _accountNumber;
  String _holderName;
  double _balance;

  BankAccount({
    required int accountNumber,
    required String holderName,
    double openingBalance = 0.0,
  })  : _accountNumber = accountNumber,
        _holderName = holderName.trim(),
        _balance = openingBalance {
    if (_holderName.isEmpty) {
      throw ArgumentError('Account holder name cannot be empty.');
    }
  }

  // Getters / Setters (encapsulation)
  int get accountNumber => _accountNumber;

  String get holderName => _holderName;
  set holderName(String value) {
    final v = value.trim();
    if (v.isEmpty) throw ArgumentError('Holder name cannot be empty.');
    _holderName = v;
  }

  double get balance => _balance;

  void _credit(double amount) {
    if (amount <= 0) {
      throw InvalidAmountException('Deposit amount must be > 0.');
    }
    _balance += amount;
  }

  void _debit(double amount) {
    if (amount <= 0) {
      throw InvalidAmountException('Withdrawal amount must be > 0.');
    }
    // Actual rules are enforced in concrete classes; this just subtracts.
    _balance -= amount;
  }

  // Abstract behavior (abstraction)
  void deposit(double amount);
  void withdraw(double amount);

  // Optional per-month maintenance hook
  void resetMonthlyCounters() {}

  // Display info (polymorphic friendly)
  void displayInfo() {
    print('----------------------------------------');
    print('Account #$accountNumber  |  ${runtimeType}');
    print('Holder  : $holderName');
    print('Balance : \$${balance.toStringAsFixed(2)}');
    print('----------------------------------------');
  }
  
  void applyInterest() {}
}

// Interface for Interest (abstraction) 
abstract class InterestBearing {
  /// Returns the interest amount that *would* be added for this period.
  double calculateInterest();

  /// Applies (credits) the calculated interest to the account.
  void applyInterest();
}

// Concrete Accounts (inheritance + polymorphism) 

class SavingsAccount extends BankAccount implements InterestBearing {
  static const double minBalance = 500.0;
  static const double interestRate = 0.02; // 2%
  static const int monthlyWithdrawalLimit = 3;

  int _withdrawalsThisMonth = 0;

  SavingsAccount({
    required super.accountNumber,
    required super.holderName,
    double openingBalance = minBalance,
  }) : super(openingBalance: openingBalance) {
    if (balance < minBalance) {
      throw MinimumBalanceException(
          'Savings requires a minimum opening balance of \$${minBalance.toStringAsFixed(2)}.');
    }
  }

  @override
  void deposit(double amount) {
    _credit(amount);
  }

  @override
  void withdraw(double amount) {
    if (_withdrawalsThisMonth >= monthlyWithdrawalLimit) {
      throw WithdrawalLimitExceededException(
          'Savings withdrawal limit ($monthlyWithdrawalLimit) reached for this month.');
    }
    if (amount > balance - minBalance) {
      throw MinimumBalanceException(
          'Withdrawal would drop below minimum balance \$${minBalance.toStringAsFixed(2)}.');
    }
    _debit(amount);
    _withdrawalsThisMonth++;
  }

  @override
  double calculateInterest() => balance * interestRate;

  @override
  void applyInterest() {
    final interest = calculateInterest();
    if (interest > 0) _credit(interest);
  }

  @override
  void resetMonthlyCounters() {
    _withdrawalsThisMonth = 0;
  }

  @override
  void displayInfo() {
    super.displayInfo();
    print('Min Balance : \$${minBalance.toStringAsFixed(2)}');
    print('Interest    : ${(interestRate * 100).toStringAsFixed(2)}%');
    print('Withdrawals : $_withdrawalsThisMonth/$monthlyWithdrawalLimit this month');
    print('----------------------------------------');
  }
}

class CheckingAccount extends BankAccount {
  static const double overdraftFee = 35.0; // charged if balance goes below 0

  CheckingAccount({
    required super.accountNumber,
    required super.holderName,
    double openingBalance = 0.0,
  }) : super(openingBalance: openingBalance);

  @override
  void deposit(double amount) {
    _credit(amount);
  }

  @override
  void withdraw(double amount) {
    final preBalance = balance;
    _debit(amount);
    // If this transaction pushed us below zero, assess overdraft fee once.
    if (preBalance >= 0 && balance < 0) {
      _debit(overdraftFee);
      // Could go further negative with the fee; that's allowed by spec.
    }
  }

  @override
  void displayInfo() {
    super.displayInfo();
    print('Overdraft fee if < \$0: \$${overdraftFee.toStringAsFixed(2)}');
    print('No withdrawal limits.');
    print('----------------------------------------');
  }
}

class PremiumAccount extends BankAccount implements InterestBearing {
  static const double minBalance = 10000.0;
  static const double interestRate = 0.05; // 5%

  PremiumAccount({
    required super.accountNumber,
    required super.holderName,
    double openingBalance = minBalance,
  }) : super(openingBalance: openingBalance) {
    if (balance < minBalance) {
      throw MinimumBalanceException(
          'Premium requires a minimum opening balance of \$${minBalance.toStringAsFixed(2)}.');
    }
  }

  @override
  void deposit(double amount) {
    _credit(amount);
  }

  @override
  void withdraw(double amount) {
    if (amount > balance - minBalance) {
      throw MinimumBalanceException(
          'Premium cannot drop below \$${minBalance.toStringAsFixed(2)}.');
    }
    _debit(amount);
  }

  @override
  double calculateInterest() => balance * interestRate;

  @override
  void applyInterest() {
    final interest = calculateInterest();
    if (interest > 0) _credit(interest);
  }

  @override
  void displayInfo() {
    super.displayInfo();
    print('Min Balance : \$${minBalance.toStringAsFixed(2)}');
    print('Interest    : ${(interestRate * 100).toStringAsFixed(2)}%');
    print('Unlimited free withdrawals.');
    print('----------------------------------------');
  }
}

// Bank (composition + polymorphism) 
class Bank {
  final Map<int, BankAccount> _accounts = {};

  // Create new accounts
  T openAccount<T extends BankAccount>(T account) {
    if (_accounts.containsKey(account.accountNumber)) {
      throw BankingException('Account number already exists.');
    }
    _accounts[account.accountNumber] = account;
    return account;
  }

  // Find by number
  BankAccount find(int accountNumber) {
    final acct = _accounts[accountNumber];
    if (acct == null) throw AccountNotFoundException(accountNumber);
    return acct;
  }

  // Transfer between accounts
  void transfer({
    required int fromAccount,
    required int toAccount,
    required double amount,
  }) {
    if (amount <= 0) {
      throw InvalidAmountException('Transfer amount must be > 0.');
    }
    final from = find(fromAccount);
    final to = find(toAccount);

    // Execute atomically (best-effort)
    try {
      from.withdraw(amount);
      to.deposit(amount);
    } catch (e) {
      rethrow;
    }
  }

  // Apply interest to all interest-bearing accounts
  void applyMonthlyInterest() {
    for (final acct in _accounts.values) {
      if (acct is InterestBearing) {
        acct.applyInterest();
      }
    }
  }

  // Reset per-month counters (e.g., savings withdrawal count)
  void newMonth() {
    for (final acct in _accounts.values) {
      acct.resetMonthlyCounters();
    }
  }

  // Report of all accounts
  void generateReport() {
    print('\n========== BANK REPORT ==========');
    for (final acct in _accounts.values) {
      acct.displayInfo(); // polymorphic
    }
    print('============ END REPORT =========\n');
  }
}

//  Demo / Example usage 
void main() {
  final bank = Bank();

  // Create accounts
  final s1 = bank.openAccount(SavingsAccount(
    accountNumber: 1001,
    holderName: 'Alice',
    openingBalance: 1200,
  ));
  final c1 = bank.openAccount(CheckingAccount(
    accountNumber: 2001,
    holderName: 'Bob',
    openingBalance: 100,
  ));
  final p1 = bank.openAccount(PremiumAccount(
    accountNumber: 3001,
    holderName: 'Charlie',
    openingBalance: 20000,
  ));

  // Basic operations
  s1.deposit(300);
  p1.withdraw(500); // stays >= 10,000

  // Checking can go negative → overdraft fee applies once if it crosses 0
  c1.withdraw(150); // 100 -> -50, fee -> -85
  c1.deposit(200);  // back to positive

  // Savings withdrawal limits and min balance checks
  try {
    s1.withdraw(400);
    s1.withdraw(200);
    s1.withdraw(50);
    // Next one will exceed the monthly limit (3)
    s1.withdraw(10);
  } catch (e) {
    print('Expected savings rule triggered: $e');
  }

  // Transfer
  bank.transfer(fromAccount: 3001, toAccount: 1001, amount: 1000);

  // Apply monthly interest to Savings & Premium
  bank.applyMonthlyInterest();

  // Report
  bank.generateReport();

  // Start a new month
  bank.newMonth();
}
