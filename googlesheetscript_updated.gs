// ====== CONFIG ======
// UPDATE THESE URLs TO YOUR LIGHTSAIL INSTANCE
const CLASSIFIER_URL = 'http://YOUR_LIGHTSAIL_IP:8000/classify';
const SYNC_URL       = 'http://YOUR_LIGHTSAIL_IP:8000/sync';
const RULE_STATS_URL = 'http://YOUR_LIGHTSAIL_IP:8000/rule-stats';
const REFRESH_RULES_URL = 'http://YOUR_LIGHTSAIL_IP:8000/refresh-rules';

// UPDATE THIS API KEY TO MATCH YOUR PRODUCTION SETTING
const API_KEY        = 'default_api_key_123';   // Change this to your production API key

const SHEET_RAW      = 'Raw';
const SHEET_REVIEW   = 'Needs_Review';
const SHEET_PUB      = 'Published';
const SHEET_MAINCAT  = 'Main_Categories';

// ====== BANK RAW → NORMALIZED CONFIG ======
const SHEET_BANKRAW = 'BankRaw_Statement';     // source pasted data
const NORMALIZE_OUTPUT_PREFIX = 'Normalized';   // new sheet name prefix
const NORMALIZE_ACCOUNT = 'HDFC1681';           // constant Account value
const NORMALIZE_CURRENCY = 'INR';               // constant Currency value

// Header synonyms so we can match varied bank exports
const BANK_HEADER_SYNONYMS = {
  date:      ['Date', 'Txn Date', 'Value Date', 'Transaction Date'],
  desc:      ['Narration', 'Description', 'Particulars', 'Details', 'Transaction Remarks'],
  withdraw:  ['Withdrawal Amount', 'Withdrawal', 'Debit', 'Dr', 'Debit Amount', 'Debits', 'WD'],
  deposit:   ['Deposit Amount', 'Deposit', 'Credit', 'Cr', 'Credit Amount', 'CR'],
  balance:   ['Closing Balance', 'Balance', 'Running Balance', 'Available Balance', 'Avail Balance'],
  amount:    ['Amount', 'Transaction Amount', 'Amt'],     // optional fallback if only one Amount column
  side:      ['Type', 'Dr/Cr', 'Debit/Credit']            // optional fallback when Amount + side indicator
};

// Expected Raw columns (A:F): Date, Description, Amount, Balance, Account, Currency
const RAW_HEADER = ['Date','Description','Amount','Balance','Account','Currency'];

function onOpen() {
  const ui = SpreadsheetApp.getUi();
  ui.createMenu('Accounting Ops')
    .addItem('0) Convert BankRaw_Statement → New normalized sheet', 'menuNormalizeBankRaw')
    .addSeparator()
    .addItem('1) Normalize & Classify (selected rows or all)', 'menuClassify')
    .addItem('2) Approve & Publish to MySQL + Learn Rules', 'menuApproveAndPublish')
    .addSeparator()
    .addItem('3) Show Rule Statistics', 'menuRuleStats')
    .addItem('4) Refresh Rules Cache', 'menuRefreshRules')
    .addToUi();
}

function menuClassify() {
  const ss = SpreadsheetApp.getActive();
  const raw = ss.getSheetByName(SHEET_RAW);
  const range = raw.getActiveRange();
  const values = (range && range.getNumRows() > 1) ? range.getValues() : raw.getDataRange().getValues();
  
  if (values.length < 2) {
    SpreadsheetApp.getUi().alert('No data to classify');
    return;
  }
  
  const header = values[0];
  const dataRows = values.slice(1);
  
  // Find column indices
  const dateIdx = header.indexOf('Date');
  const descIdx = header.indexOf('Description');
  const amountIdx = header.indexOf('Amount');
  const balanceIdx = header.indexOf('Balance');
  const accountIdx = header.indexOf('Account');
  const currencyIdx = header.indexOf('Currency');
  
  if (dateIdx === -1 || descIdx === -1 || amountIdx === -1) {
    SpreadsheetApp.getUi().alert('Required columns (Date, Description, Amount) not found');
    return;
  }
  
  // Prepare data for API
  const rows = dataRows.map(row => ({
    date: row[dateIdx],
    description: row[descIdx],
    amount: parseFloat(row[amountIdx]) || 0,
    balance: balanceIdx !== -1 ? parseFloat(row[balanceIdx]) : null,
    account: accountIdx !== -1 ? row[accountIdx] : '',
    currency: currencyIdx !== -1 ? row[currencyIdx] : 'INR'
  }));
  
  try {
    const res = UrlFetchApp.fetch(CLASSIFIER_URL, {
      method: 'POST',
      contentType: 'application/json',
      headers: { 'X-API-Key': API_KEY },
      payload: JSON.stringify({ rows: rows })
    });
    
    if (res.getResponseCode() !== 200) {
      throw new Error(`API returned ${res.getResponseCode()}: ${res.getContentText()}`);
    }
    
    const result = JSON.parse(res.getContentText());
    
    // Create or clear review sheet
    let reviewSheet = ss.getSheetByName(SHEET_REVIEW);
    if (!reviewSheet) {
      reviewSheet = ss.insertSheet(SHEET_REVIEW);
    } else {
      reviewSheet.clear();
    }
    
    // Add headers
    const reviewHeaders = [...RAW_HEADER, 'Vendor', 'Rule Hit', 'Main Category', 'Sub Category', 'Confidence'];
    reviewSheet.getRange(1, 1, 1, reviewHeaders.length).setValues([reviewHeaders]);
    
    // Add classified data
    const reviewData = result.map((item, index) => [
      item.date,
      item.description,
      item.amount,
      item.balance,
      item.account,
      item.currency,
      item.vendor,
      item.rule_hit,
      item.main_category_suggested,
      item.sub_category_suggested,
      item.confidence
    ]);
    
    if (reviewData.length > 0) {
      reviewSheet.getRange(2, 1, reviewData.length, reviewData[0].length).setValues(reviewData);
    }
    
    SpreadsheetApp.getUi().alert(`Classified ${result.length} transactions. Check '${SHEET_REVIEW}' sheet.`);
    
  } catch (error) {
    SpreadsheetApp.getUi().alert(`Error: ${error.toString()}`);
  }
}

function menuApproveAndPublish() {
  const ss = SpreadsheetApp.getActive();
  const reviewSheet = ss.getSheetByName(SHEET_REVIEW);
  
  if (!reviewSheet) {
    SpreadsheetApp.getUi().alert(`No '${SHEET_REVIEW}' sheet found. Run classification first.`);
    return;
  }
  
  const range = reviewSheet.getActiveRange();
  const values = (range && range.getNumRows() > 1) ? range.getValues() : reviewSheet.getDataRange().getValues();
  
  if (values.length < 2) {
    SpreadsheetApp.getUi().alert('No data to publish');
    return;
  }
  
  const header = values[0];
  const dataRows = values.slice(1);
  
  // Find column indices
  const dateIdx = header.indexOf('Date');
  const descIdx = header.indexOf('Description');
  const amountIdx = header.indexOf('Amount');
  const balanceIdx = header.indexOf('Balance');
  const accountIdx = header.indexOf('Account');
  const currencyIdx = header.indexOf('Currency');
  const vendorIdx = header.indexOf('Vendor');
  const ruleHitIdx = header.indexOf('Rule Hit');
  const mainCatIdx = header.indexOf('Main Category');
  const subCatIdx = header.indexOf('Sub Category');
  const confIdx = header.indexOf('Confidence');
  
  if (dateIdx === -1 || descIdx === -1 || amountIdx === -1) {
    SpreadsheetApp.getUi().alert('Required columns not found');
    return;
  }
  
  // Prepare data for API
  const rows = dataRows.map(row => ({
    date: row[dateIdx],
    description: row[descIdx],
    amount: parseFloat(row[amountIdx]) || 0,
    balance: balanceIdx !== -1 ? parseFloat(row[balanceIdx]) : null,
    account: accountIdx !== -1 ? row[accountIdx] : '',
    currency: currencyIdx !== -1 ? row[currencyIdx] : 'INR',
    vendor: vendorIdx !== -1 ? row[vendorIdx] : '',
    main_category: mainCatIdx !== -1 ? row[mainCatIdx] : '',
    sub_category: subCatIdx !== -1 ? row[subCatIdx] : '',
    confidence: confIdx !== -1 ? parseFloat(row[confIdx]) : 0,
    rule_hit: ruleHitIdx !== -1 ? row[ruleHitIdx] : ''
  }));
  
  try {
    const res = UrlFetchApp.fetch(SYNC_URL, {
      method: 'POST',
      contentType: 'application/json',
      headers: { 'X-API-Key': API_KEY },
      payload: JSON.stringify({ rows: rows })
    });
    
    if (res.getResponseCode() !== 200) {
      throw new Error(`API returned ${res.getResponseCode()}: ${res.getContentText()}`);
    }
    
    const result = JSON.parse(res.getContentText());
    
    if (result.success) {
      // Move data to published sheet
      let pubSheet = ss.getSheetByName(SHEET_PUB);
      if (!pubSheet) {
        pubSheet = ss.insertSheet(SHEET_PUB);
        pubSheet.getRange(1, 1, 1, header.length).setValues([header]);
      }
      
      const lastRow = pubSheet.getLastRow();
      pubSheet.getRange(lastRow + 1, 1, dataRows.length, dataRows[0].length).setValues(dataRows);
      
      // Clear review sheet
      reviewSheet.clear();
      reviewSheet.getRange(1, 1, 1, header.length).setValues([header]);
      
      SpreadsheetApp.getUi().alert(`Success! Published ${result.published_count} transactions. Learned ${result.rules_created} new rules.`);
    } else {
      SpreadsheetApp.getUi().alert(`Error: ${result.message}`);
    }
    
  } catch (error) {
    SpreadsheetApp.getUi().alert(`Error: ${error.toString()}`);
  }
}

function menuRuleStats() {
  try {
    const res = UrlFetchApp.fetch(RULE_STATS_URL, {
      method: 'GET',
      headers: { 'X-API-Key': API_KEY }
    });
    
    if (res.getResponseCode() !== 200) {
      throw new Error(`API returned ${res.getResponseCode()}: ${res.getContentText()}`);
    }
    
    const result = JSON.parse(res.getContentText());
    
    let message = `Rule Statistics:\n\n`;
    message += `Total Rules: ${result.total_rules}\n`;
    message += `Auto-learned Rules: ${result.auto_learned_rules}\n`;
    message += `Manual Rules: ${result.manual_rules}\n\n`;
    message += `Database Stats:\n`;
    message += `Total Transactions: ${result.database_stats.total_transactions}\n`;
    message += `Verified Transactions: ${result.database_stats.verified_transactions}\n`;
    message += `High Confidence: ${result.database_stats.high_confidence_transactions}\n\n`;
    message += `Top Categories:\n`;
    
    result.top_categories.forEach((cat, index) => {
      message += `${index + 1}. ${cat.category}: ${cat.count} transactions\n`;
    });
    
    SpreadsheetApp.getUi().alert(message);
    
  } catch (error) {
    SpreadsheetApp.getUi().alert(`Error: ${error.toString()}`);
  }
}

function menuRefreshRules() {
  try {
    const res = UrlFetchApp.fetch(REFRESH_RULES_URL, {
      method: 'POST',
      headers: { 'X-API-Key': API_KEY }
    });
    
    if (res.getResponseCode() !== 200) {
      throw new Error(`API returned ${res.getResponseCode()}: ${res.getContentText()}`);
    }
    
    const result = JSON.parse(res.getContentText());
    
    if (result.ok) {
      SpreadsheetApp.getUi().alert(`Rules cache refreshed! Total rules: ${result.total_rules}`);
    } else {
      SpreadsheetApp.getUi().alert(`Error: ${result.message}`);
    }
    
  } catch (error) {
    SpreadsheetApp.getUi().alert(`Error: ${error.toString()}`);
  }
}

function menuNormalizeBankRaw() {
  const ss = SpreadsheetApp.getActive();
  const bankRawSheet = ss.getSheetByName(SHEET_BANKRAW);
  
  if (!bankRawSheet) {
    SpreadsheetApp.getUi().alert(`No '${SHEET_BANKRAW}' sheet found. Please create it and paste your bank statement data.`);
    return;
  }
  
  const values = bankRawSheet.getDataRange().getValues();
  if (values.length < 2) {
    SpreadsheetApp.getUi().alert('No data found in BankRaw_Statement sheet');
    return;
  }
  
  const header = values[0];
  const dataRows = values.slice(1);
  
  // Find column indices using synonyms
  const findColumnIndex = (synonyms) => {
    for (const synonym of synonyms) {
      const index = header.findIndex(h => h && h.toString().toLowerCase().includes(synonym.toLowerCase()));
      if (index !== -1) return index;
    }
    return -1;
  };
  
  const dateIdx = findColumnIndex(BANK_HEADER_SYNONYMS.date);
  const descIdx = findColumnIndex(BANK_HEADER_SYNONYMS.desc);
  const withdrawIdx = findColumnIndex(BANK_HEADER_SYNONYMS.withdraw);
  const depositIdx = findColumnIndex(BANK_HEADER_SYNONYMS.deposit);
  const balanceIdx = findColumnIndex(BANK_HEADER_SYNONYMS.balance);
  const amountIdx = findColumnIndex(BANK_HEADER_SYNONYMS.amount);
  const sideIdx = findColumnIndex(BANK_HEADER_SYNONYMS.side);
  
  if (dateIdx === -1 || descIdx === -1) {
    SpreadsheetApp.getUi().alert('Required columns (Date, Description) not found in bank statement');
    return;
  }
  
  // Process data
  const normalizedData = dataRows.map(row => {
    let amount = 0;
    
    // Calculate amount based on available columns
    if (withdrawIdx !== -1 && depositIdx !== -1) {
      const withdraw = parseFloat(row[withdrawIdx]) || 0;
      const deposit = parseFloat(row[depositIdx]) || 0;
      amount = deposit - withdraw; // Positive for credit, negative for debit
    } else if (amountIdx !== -1 && sideIdx !== -1) {
      const amt = parseFloat(row[amountIdx]) || 0;
      const side = row[sideIdx] ? row[sideIdx].toString().toLowerCase() : '';
      amount = side.includes('credit') || side.includes('cr') ? amt : -amt;
    } else if (amountIdx !== -1) {
      amount = parseFloat(row[amountIdx]) || 0;
    }
    
    return [
      row[dateIdx],
      row[descIdx],
      amount,
      balanceIdx !== -1 ? (parseFloat(row[balanceIdx]) || 0) : '',
      NORMALIZE_ACCOUNT,
      NORMALIZE_CURRENCY
    ];
  });
  
  // Create normalized sheet
  const sheetName = `${NORMALIZE_OUTPUT_PREFIX}_${new Date().toISOString().slice(0, 10)}`;
  let normalizedSheet = ss.getSheetByName(sheetName);
  if (normalizedSheet) {
    ss.deleteSheet(normalizedSheet);
  }
  normalizedSheet = ss.insertSheet(sheetName);
  
  // Add headers and data
  normalizedSheet.getRange(1, 1, 1, RAW_HEADER.length).setValues([RAW_HEADER]);
  normalizedSheet.getRange(2, 1, normalizedData.length, RAW_HEADER.length).setValues(normalizedData);
  
  SpreadsheetApp.getUi().alert(`Created normalized sheet '${sheetName}' with ${normalizedData.length} transactions.`);
}
