import 'dart:math';
import 'package:charts_common/common.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:invoiceninja_flutter/constants.dart';
import 'package:invoiceninja_flutter/data/models/entities.dart';
import 'package:invoiceninja_flutter/redux/company/company_selectors.dart';
import 'package:invoiceninja_flutter/redux/dashboard/dashboard_selectors.dart';
import 'package:invoiceninja_flutter/ui/app/forms/date_range_picker.dart';
import 'package:invoiceninja_flutter/ui/app/loading_indicator.dart';
import 'package:invoiceninja_flutter/ui/dashboard/dashboard_chart.dart';
import 'package:invoiceninja_flutter/ui/dashboard/dashboard_screen_vm.dart';
import 'package:invoiceninja_flutter/utils/formatting.dart';
import 'package:invoiceninja_flutter/utils/localization.dart';

class DashboardPanels extends StatelessWidget {
  const DashboardPanels({
    Key key,
    @required this.viewModel,
    @required this.scrollController,
  }) : super(key: key);

  final DashboardVM viewModel;
  final ScrollController scrollController;

  void _showDateOptions(BuildContext context) {
    showDialog<DateRangePicker>(
        context: context,
        builder: (BuildContext context) {
          return DateRangePicker(
              state: viewModel.dashboardUIState,
              onSettingsChanged: viewModel.onSettingsChanged);
        });
  }

  Widget _header(BuildContext context) {
    final uiState = viewModel.dashboardUIState;
    final state = viewModel.state;
    final company = state.company;
    final clientMap = state.clientState.map;
    final groupMap = state.groupState.map;

    // Add "All" if more than one currency
    final currencies = memoizedGetCurrencyIds(company, clientMap, groupMap);
    if (currencies.length > 1 && !currencies.contains(kCurrencyAll)) {
      currencies.insert(0, kCurrencyAll);
    }
    final localization = AppLocalization.of(context);
    final hasMultipleCurrencies =
        memoizedHasMultipleCurrencies(company, clientMap, groupMap);

    return Material(
      color: Theme.of(context).cardColor,
      elevation: 6.0,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Row(
          children: <Widget>[
            SizedBox(width: 8.0),
            IconButton(
              icon: Icon(Icons.navigate_before),
              onPressed: () => viewModel.onOffsetChanged(1),
            ),
            SizedBox(width: 8.0),
            IconButton(
              icon: Icon(Icons.navigate_next),
              onPressed: viewModel.isNextEnabled
                  ? () => viewModel.onOffsetChanged(-1)
                  : null,
            ),
            SizedBox(width: 16),
            Expanded(
              child: InkWell(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        formatDateRange(uiState.startDate(company),
                            uiState.endDate(company), context),
                        style: Theme.of(context)
                            .textTheme
                            .headline6
                            .copyWith(fontSize: 18),
                      ),
                    ),
                    SizedBox(width: 6.0),
                    Icon(Icons.arrow_drop_down),
                  ],
                ),
                onTap: () => _showDateOptions(context),
              ),
            ),
            if (hasMultipleCurrencies) ...[
              SizedBox(
                width: 12,
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  items: memoizedGetCurrencyIds(company, clientMap, groupMap)
                      .map((currencyId) => DropdownMenuItem<String>(
                            child: Text(currencyId == kCurrencyAll
                                ? localization.all
                                : viewModel.currencyMap[currencyId]?.code),
                            value: currencyId,
                          ))
                      .toList(),
                  onChanged: (currencyId) =>
                      viewModel.onCurrencyChanged(currencyId),
                  value: state.dashboardUIState.currencyId,
                ),
              ),
              SizedBox(
                width: 12,
              ),
            ]
            /*
              Row(
                mainAxisSize: MainAxisSize.max,
                children: <Widget>[
                  SizedBox(width: 8.0),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      items: memoizedGetCurrencyIds(company, clientMap, groupMap)
                          .map((currencyId) => DropdownMenuItem<String>(
                                child: Text(currencyId == kCurrencyAll
                                    ? localization.all
                                    : viewModel.currencyMap[currencyId]?.code),
                                value: currencyId,
                              ))
                          .toList(),
                      onChanged: (currencyId) =>
                          viewModel.onCurrencyChanged(currencyId),
                      value: state.dashboardUIState.currencyId,
                    ),
                  ),
                  SizedBox(width: 16.0),
                ],
              ),
               */
          ],
        ),
      ),
    );
  }

  Widget _paymentChart({
    @required BuildContext context,
    @required Function(List<String>) onDateSelected,
  }) {
    final settings = viewModel.dashboardUIState;
    final state = viewModel.state;
    final isLoaded = state.isLoaded || state.paymentState.list.isNotEmpty;
    final currentData = memoizedChartPayments(
        state.staticState.currencyMap,
        state.company,
        settings,
        state.invoiceState.map,
        state.clientState.map,
        state.groupState.map,
        state.paymentState.map);

    List<ChartDataGroup> previousData;
    if (settings.enableComparison) {
      previousData = memoizedChartPayments(
          state.staticState.currencyMap,
          state.company,
          settings.rebuild((b) => b..offset += 1),
          state.invoiceState.map,
          state.clientState.map,
          state.groupState.map,
          state.paymentState.map);
    }

    return _DashboardPanel(
      viewModel: viewModel,
      context: context,
      currentData: currentData,
      previousData: previousData,
      isLoaded: isLoaded,
      title: AppLocalization.of(context).payments,
      onDateSelected: (index, date) =>
          onDateSelected(currentData[index].entityMap[date]),
    );
  }

  Widget _quoteChart({
    @required BuildContext context,
    @required Function(List<String>) onDateSelected,
  }) {
    final settings = viewModel.dashboardUIState;
    final state = viewModel.state;
    final isLoaded = state.isLoaded || state.quoteState.list.isNotEmpty;
    final currentData = memoizedChartQuotes(
      state.staticState.currencyMap,
      state.company,
      settings,
      state.quoteState.map,
      state.clientState.map,
      state.groupState.map,
    );

    List<ChartDataGroup> previousData;
    if (settings.enableComparison) {
      previousData = memoizedChartQuotes(
        state.staticState.currencyMap,
        state.company,
        settings.rebuild((b) => b..offset += 1),
        state.quoteState.map,
        state.clientState.map,
        state.groupState.map,
      );
    }

    return _DashboardPanel(
      viewModel: viewModel,
      context: context,
      currentData: currentData,
      previousData: previousData,
      isLoaded: isLoaded,
      title: AppLocalization.of(context).quotes,
      onDateSelected: (index, date) =>
          onDateSelected(currentData[index].entityMap[date]),
    );
  }

  Widget _taskChart({
    @required BuildContext context,
    @required Function(List<String>) onDateSelected,
  }) {
    final settings = viewModel.dashboardUIState;
    final state = viewModel.state;
    final isLoaded = state.isLoaded || state.taskState.list.isNotEmpty;
    final currentData = memoizedChartTasks(
      state.staticState.currencyMap,
      state.company,
      settings,
      state.taskState.map,
      state.invoiceState.map,
      state.projectState.map,
      state.groupState.map,
      state.clientState.map,
    );

    List<ChartDataGroup> previousData;
    if (settings.enableComparison) {
      previousData = memoizedChartTasks(
        state.staticState.currencyMap,
        state.company,
        settings.rebuild((b) => b..offset += 1),
        state.taskState.map,
        state.invoiceState.map,
        state.projectState.map,
        state.groupState.map,
        state.clientState.map,
      );
    }

    return _DashboardPanel(
      viewModel: viewModel,
      context: context,
      currentData: currentData,
      previousData: previousData,
      isLoaded: isLoaded,
      title: AppLocalization.of(context).tasks,
      onDateSelected: (index, date) =>
          onDateSelected(currentData[index].entityMap[date]),
    );
  }

  Widget _expenseChart({
    @required BuildContext context,
    @required Function(List<String>) onDateSelected,
  }) {
    final settings = viewModel.dashboardUIState;
    final state = viewModel.state;
    final isLoaded = state.isLoaded || state.expenseState.list.isNotEmpty;
    final currentData = memoizedChartExpenses(
        state.staticState.currencyMap,
        state.company,
        settings,
        state.invoiceState.map,
        state.expenseState.map);

    List<ChartDataGroup> previousData;
    if (settings.enableComparison) {
      previousData = memoizedChartExpenses(
          state.staticState.currencyMap,
          state.company,
          settings.rebuild((b) => b..offset += 1),
          state.invoiceState.map,
          state.expenseState.map);
    }

    return _DashboardPanel(
      viewModel: viewModel,
      context: context,
      currentData: currentData,
      previousData: previousData,
      isLoaded: isLoaded,
      title: AppLocalization.of(context).expenses,
      onDateSelected: (index, date) =>
          onDateSelected(currentData[index].entityMap[date]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = viewModel.state;
    final company = state.company;

    if (!state.staticState.isLoaded) {
      return LoadingIndicator();
    }

    return Stack(
      children: <Widget>[
        ListView(
          controller: scrollController,
          children: <Widget>[
            SizedBox(
              height: 74.0,
            ),
            if (company.isModuleEnabled(EntityType.invoice))
              _InvoiceChart(
                  viewModel: viewModel,
                  context: context,
                  onDateSelected: (entityIds) => viewModel.onSelectionChanged(
                      EntityType.invoice, entityIds)),
            if (company.isModuleEnabled(EntityType.invoice))
              _paymentChart(
                  context: context,
                  onDateSelected: (entityIds) => viewModel.onSelectionChanged(
                      EntityType.payment, entityIds)),
            if (company.isModuleEnabled(EntityType.quote))
              _quoteChart(
                  context: context,
                  onDateSelected: (entityIds) => viewModel.onSelectionChanged(
                      EntityType.quote, entityIds)),
            if (company.isModuleEnabled(EntityType.task))
              _taskChart(
                  context: context,
                  onDateSelected: (entityIds) =>
                      viewModel.onSelectionChanged(EntityType.task, entityIds)),
            if (company.isModuleEnabled(EntityType.expense))
              _expenseChart(
                  context: context,
                  onDateSelected: (entityIds) => viewModel.onSelectionChanged(
                      EntityType.expense, entityIds)),
            SizedBox(
              height: 500,
            )
          ],
        ),
        ConstrainedBox(
          child: _header(context),
          constraints: BoxConstraints.loose(
            Size(double.infinity, 74.0),
          ),
        ),
      ],
    );
  }
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({
    @required this.viewModel,
    @required this.context,
    @required this.title,
    @required this.currentData,
    @required this.previousData,
    @required this.isLoaded,
    @required this.onDateSelected,
  });

  final DashboardVM viewModel;
  final BuildContext context;
  final String title;
  final List<ChartDataGroup> currentData;
  final List<ChartDataGroup> previousData;
  final bool isLoaded;
  final Function(int, String) onDateSelected;

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalization.of(context);
    final settings = viewModel.dashboardUIState;
    final state = viewModel.state;

    if (!isLoaded) {
      return LoadingIndicator(useCard: true);
    }

    currentData.forEach((dataGroup) {
      final index = currentData.indexOf(dataGroup);
      dataGroup.chartSeries = <Series<dynamic, DateTime>>[
        charts.Series<ChartMoneyData, DateTime>(
          domainFn: (ChartMoneyData chartData, _) => chartData.date,
          measureFn: (ChartMoneyData chartData, _) => chartData.amount,
          colorFn: (ChartMoneyData chartData, _) =>
              charts.MaterialPalette.blue.shadeDefault,
          id: DashboardChart.PERIOD_CURRENT,
          displayName: settings.enableComparison ? localization.current : title,
          data: dataGroup.rawSeries,
        )
      ];

      if (settings.enableComparison) {
        final List<ChartMoneyData> previous = [];
        final currentSeries = dataGroup.rawSeries;
        final previousSeries = previousData[index].rawSeries;

        dataGroup.previousTotal = previousData[index].total;

        for (int i = 0;
            i < min(currentSeries.length, previousSeries.length);
            i++) {
          previous.add(
              ChartMoneyData(currentSeries[i].date, previousSeries[i].amount));
        }

        dataGroup.chartSeries.add(
          charts.Series<ChartMoneyData, DateTime>(
            domainFn: (ChartMoneyData chartData, _) => chartData.date,
            measureFn: (ChartMoneyData chartData, _) => chartData.amount,
            colorFn: (ChartMoneyData chartData, _) =>
                charts.MaterialPalette.gray.shadeDefault,
            id: DashboardChart.PERIOD_PREVIOUS,
            displayName: localization.previous,
            data: previous,
          ),
        );
      }
    });

    return DashboardChart(
      data: currentData,
      title: title,
      onDateSelected: onDateSelected,
      currencyId: (settings.currencyId ?? '').isNotEmpty
          ? settings.currencyId
          : state.company.currencyId,
    );
  }
}

class _InvoiceChart extends StatelessWidget {
  const _InvoiceChart({
    @required this.viewModel,
    @required this.context,
    @required this.onDateSelected,
  });

  final DashboardVM viewModel;
  final BuildContext context;
  final Function(List<String>) onDateSelected;

  @override
  Widget build(BuildContext context) {
    final settings = viewModel.dashboardUIState;
    final state = viewModel.state;
    final isLoaded = state.isLoaded || state.invoiceState.list.isNotEmpty;
    final currentData = memoizedChartInvoices(
        state.staticState.currencyMap,
        state.company,
        settings,
        state.invoiceState.map,
        state.clientState.map,
        state.groupState.map);

    List<ChartDataGroup> previousData;
    if (settings.enableComparison) {
      previousData = memoizedPreviousChartInvoices(
        state.staticState.currencyMap,
        state.company,
        settings.rebuild((b) => b..offset += 1),
        state.invoiceState.map,
        state.clientState.map,
        state.groupState.map,
      );
    }

    return _DashboardPanel(
      viewModel: viewModel,
      context: context,
      currentData: currentData,
      previousData: previousData,
      isLoaded: isLoaded,
      title: AppLocalization.of(context).invoices,
      onDateSelected: (index, date) =>
          onDateSelected(currentData[index].entityMap[date]),
    );
  }
}
