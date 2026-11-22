-- Yearly trend: number of invoices, net revenue, taxes, gross total
SELECT 
    date_part('year', InvoiceDate::DATE) AS Year,
    count(DISTINCT SalesInvoiceID)       AS InvoiceCount,
    round(sum(SubTotal), 2)              AS NetRevenue,
    round(sum(GrandTotal), 2)            AS TotalRevenue
FROM SalesInvoice
GROUP BY Year
ORDER BY Year;

-- Monthly trend: number of invoices, net revenue, taxes, gross total
SELECT 
    strftime(InvoiceDate::DATE, '%Y-%m') AS Month,
    count(DISTINCT SalesInvoiceID)       AS InvoiceCount,
    round(sum(SubTotal), 2)              AS NetRevenue,
    round(sum(GrandTotal), 2)            AS TotalRevenue
FROM SalesInvoice
GROUP BY Month
ORDER BY Month;

-- Profitability by item group

SELECT 
    i.ItemGroup,
    round(sum(sil.LineTotal), 2) AS Przychod,
    round(sum(sil.Quantity * i.StandardCost), 2) AS SzacowanyKosztCOGS,
    round(sum(sil.LineTotal) - sum(sil.Quantity * i.StandardCost), 2) AS ZyskBrutto,
    round((sum(sil.LineTotal) - sum(sil.Quantity * i.StandardCost)) / sum(sil.LineTotal) * 100, 2) AS MarzaProcentowa
FROM SalesInvoiceLine sil
JOIN Item i ON sil.ItemID = i.ItemID
GROUP BY i.ItemGroup
ORDER BY Przychod DESC;

-- Top 10 items by Revenue vs top 10 items by percent margin

SELECT
    i.ItemCode,
    i.ItemName, 
    i.ItemGroup, 
    round(sum(sil.LineTotal), 2) AS Revenue,
    round(sum(sil.LineTotal) - sum(sil.Quantity * i.StandardCost), 2) AS GrossProfit,
    round((sum(sil.LineTotal) - sum(sil.Quantity * i.StandardCost)) / sum(sil.LineTotal) * 100, 2) AS PercentMargin
FROM SalesInvoiceLine sil
JOIN Item i ON sil.ItemID = i.ItemID
GROUP BY i.ItemCode, i.ItemName, i.ItemGroup
ORDER BY Revenue DESC
LIMIT 10;



SELECT
    i.ItemCode,
    i.ItemName, 
    i.ItemGroup, 
    round(sum(sil.LineTotal), 2) AS Revenue,
    round(sum(sil.LineTotal) - sum(sil.Quantity * i.StandardCost), 2) AS GrossProfit,
    round((sum(sil.LineTotal) - sum(sil.Quantity * i.StandardCost)) / sum(sil.LineTotal) * 100, 2) AS PercentMargin
FROM SalesInvoiceLine sil
JOIN Item i ON sil.ItemID = i.ItemID
GROUP BY i.ItemCode, i.ItemName, i.ItemGroup
ORDER BY PercentMargin DESC
LIMIT 10;


-- Struktura narzutu płacowego (Netto vs Podatki vs ZUS/Benefity)
SELECT 
    date_part('year', pp.PeriodStartDate::DATE) AS Rok,
    round(sum(pr.GrossPay), 2)                  AS WynagrodzeniaBrutto,
    round(sum(pr.NetPay), 2)                    AS WyplatyNetto,
    round(sum(pr.EmployerPayrollTax), 2)        AS PodatkiPracodawcy,
    round(sum(pr.EmployerBenefits), 2)          AS BenefityPracodawcy,
    -- Łączny koszt pracodawcy:
    round(sum(pr.GrossPay + pr.EmployerPayrollTax + pr.EmployerBenefits), 2) AS CalkowityKosztPracownikow
FROM PayrollRegister pr
JOIN PayrollPeriod pp ON pr.PayrollPeriodID = pp.PayrollPeriodID
GROUP BY Rok
ORDER BY Rok;

-- Cost centers (Koszty pracowników wg działów)
SELECT 
    cc.CostCenterName,
    count(DISTINCT pr.EmployeeID) AS LiczbaPracownikow,
    round(sum(pr.GrossPay + pr.EmployerPayrollTax + pr.EmployerBenefits), 2) AS KosztCalkowity,
    round(avg(pr.GrossPay), 2) AS SredniaPlacaBruttoNaOkres
FROM PayrollRegister pr
JOIN CostCenter cc ON pr.CostCenterID = cc.CostCenterID
GROUP BY cc.CostCenterName
ORDER BY KosztCalkowity DESC;


-- Analiza nadgodzin (skąd biorą się dodatkowe koszty robocizny)
SELECT 
    ReasonCode,
    count(*) AS LiczbaWnioskow,
    round(sum(RequestedHours), 1) AS ZgloszoneGodziny,
    round(sum(ApprovedHours), 1)  AS ZatwierdzoneGodziny
FROM OvertimeApproval
GROUP BY ReasonCode
ORDER BY ZatwierdzoneGodziny DESC;
