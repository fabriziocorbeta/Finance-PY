export interface Transaction {
  id: string;
  date: string;
  amount: string;
  name: string;
  accountName: string;
}

export async function fetchRecentTransactions(accessToken: string): Promise<Transaction[]> {
  const response = await fetch('https://finance.cd-co.com.py/api/v1/transactions?per_page=20', {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  const body = await response.json();

  if (!response.ok) {
    throw new Error(body.error ?? `Unexpected status ${response.status}`);
  }

  return body.transactions.map((t: any) => ({
    id: t.id,
    date: t.date,
    amount: t.amount,
    name: t.name,
    accountName: t.account.name,
  }));
}
