/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : GenericDashboardControllerTest
 * Author          : Deepak Singh
 * Created Date    : Jan 13, 2026
 * Last Modified By: Deepak Singh
 * Last Modified On: Jan 13, 2026
 * Description     : This class implements for showing the generic dashboard for any object
 *  
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Jan 13, 2026  │ Deepak Singh   │ Initial version
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
public with sharing class GenericDashboardController {

   @AuraEnabled(cacheable=true)
    public static Map<String, Object> getDashboardData(
        String objectApiName,
        String statusFieldApi,
        String dateFieldApi,
        Date fromDate,
        Date toDate,
        String ownerId
    ) {
        Map<String, Object> result = new Map<String, Object>();

        String whereClause = ' WHERE Id != null';

        if (fromDate != null) {
            whereClause += ' AND ' + dateFieldApi + ' >= :fromDate';
        }
        if (toDate != null) {
            whereClause += ' AND ' + dateFieldApi + ' <= :toDate';
        }
        if (String.isNotBlank(ownerId)) {
            whereClause += ' AND OwnerId = :ownerId';
        }

        String soql =
            'SELECT ' + statusFieldApi + ' statusVal, ' +
            'Owner.Name ownerName, COUNT(Id) cnt ' +
            'FROM ' + objectApiName +
            whereClause +
            ' GROUP BY ' + statusFieldApi + ', Owner.Name';

        List<AggregateResult> records = Database.query(soql);

        //  USER → STATUS → COUNT
        Map<String, Map<String, Integer>> userStatusMap = new Map<String, Map<String, Integer>>();
        Map<String, Integer> statusTotals = new Map<String, Integer>();
        Set<String> statuses = new Set<String>();
        Integer grandTotal = 0;

        for (AggregateResult ar : records) {

            String status = String.valueOf(ar.get('statusVal'));
            String userName = String.valueOf(ar.get('ownerName'));
            Integer countVal = (Integer) ar.get('cnt');

            grandTotal += countVal;
            statuses.add(status);

            // Status totals
            statusTotals.put(
                status,
                (statusTotals.containsKey(status) ? statusTotals.get(status) : 0) + countVal
            );

            // User → Status map
            if (!userStatusMap.containsKey(userName)) {
                userStatusMap.put(userName, new Map<String, Integer>());
            }
            userStatusMap.get(userName).put(status, countVal);
        }

        result.put('statusTotals', statusTotals);
        result.put('userStatusMap', userStatusMap);
        result.put('statuses', new List<String>(statuses));
        result.put('grandTotal', grandTotal);

        return result;
    }


    @AuraEnabled(cacheable=true)
    public static List<User> getUsers() {
        return [
            SELECT Id, Name
            FROM User
            ORDER BY Name
        ];
    }
	
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getDashboardByLabelFields(
        String objectApiName,
        String dateFieldApi,
        Date fromDate,
        Date toDate,
        Id ownerId,
        String dashboardPicklistFields
    ) {
        Map<String, Object> response = new Map<String, Object>();

        // Read label
        String labelValue = dashboardPicklistFields;
        List<String> fieldApiNames = labelValue.split(',');

        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectApiName);
        Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();

        String whereClause = ' WHERE Id != null';
        if (fromDate != null) whereClause += ' AND ' + dateFieldApi + ' >= :fromDate';
        if (toDate != null) whereClause += ' AND ' + dateFieldApi + ' <= :toDate';
        if (ownerId != null) whereClause += ' AND OwnerId = :ownerId';

        Map<String, Object> tables = new Map<String, Object>();

        // Loop label fields
        for (String fieldApi : fieldApiNames) {

            fieldApi = fieldApi.trim();
            if (!fieldMap.containsKey(fieldApi)) continue;

            Schema.DescribeFieldResult dfr = fieldMap.get(fieldApi).getDescribe();
            if (dfr.getType() != Schema.DisplayType.Picklist) continue;

            // Picklist values
            List<String> picklistValues = new List<String>();
            for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
                picklistValues.add(pe.getLabel());
            }

            // Aggregate query
            String soql =
                'SELECT ' + fieldApi + ' plVal, Owner.Name ownerName, COUNT(Id) cnt ' +
                'FROM ' + objectApiName +
                whereClause +
                ' GROUP BY ' + fieldApi + ', Owner.Name';

            List<AggregateResult> rows = Database.query(soql);

            // USER → PICKLIST → COUNT
            Map<String, Map<String, Integer>> userMap = new Map<String, Map<String, Integer>>();

            for (AggregateResult ar : rows) {
                String user = (String) ar.get('ownerName');
                String val = String.valueOf(ar.get('plVal'));
                Integer countVal = (Integer) ar.get('cnt');

                if (!userMap.containsKey(user)) {
                    userMap.put(user, new Map<String, Integer>());
                }
                userMap.get(user).put(val, countVal);
            }

            Map<String, Object> table = new Map<String, Object>();
            table.put('picklistValues', picklistValues);
            table.put('userData', userMap);

            tables.put(fieldApi, table);
        }

        response.put('tables', tables);
        return response;
    }
}