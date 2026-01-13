@IsTest
public class GenericDashboardControllerTest {

    @TestSetup
    static void setupData() {

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User u = new User(
            FirstName = 'Test',
            LastName = 'User',
            Alias = 'tusr',
            Email = 'testuser@test.com',
            Username = 'testuser' + System.currentTimeMillis() + '@test.com',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_IN',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;

        insert new List<Opportunity>{
            new Opportunity(
                Name = 'Opp 1',
                StageName = 'Prospecting',
                CloseDate = Date.today(),
                OwnerId = u.Id,
                Amount = 1000
            ),
            new Opportunity(
                Name = 'Opp 2',
                StageName = 'Closed Won',
                CloseDate = Date.today(),
                OwnerId = u.Id,
                Amount = 2000
            )
        };
    }

    /* ---------------------------------------------------
       Covers getDashboardByLabelFields COMPLETELY
    --------------------------------------------------- */
    @IsTest
    static void testDashboardByPicklistFields() {

        User u = [SELECT Id FROM User LIMIT 1];

        Test.startTest();

        Map<String, Object> response =
            GenericDashboardController.getDashboardByLabelFields(
                'Opportunity',
                'CloseDate',
                Date.today().addDays(-1),
                Date.today().addDays(1),
                u.Id,
                'StageName' // 👈 forces Picklist describe path
            );

        Test.stopTest();

        System.assertNotEquals(null, response);
        System.assert(response.containsKey('tables'));

        Map<String, Object> tables =
            (Map<String, Object>) response.get('tables');

        // 🔥 This assertion GUARANTEES the block executed
        System.assertEquals(true, tables.containsKey('StageName'));

        Map<String, Object> stageTable =
            (Map<String, Object>) tables.get('StageName');

        System.assert(stageTable.containsKey('picklistValues'));
        System.assert(stageTable.containsKey('userData'));
    }

    /* ---------------------------------------------------
       Covers getDashboardData owner + date paths
    --------------------------------------------------- */
    @IsTest
    static void testGetDashboardDataWithOwner() {

        User u = [SELECT Id FROM User LIMIT 1];

        Test.startTest();

        Map<String, Object> result =
            GenericDashboardController.getDashboardData(
                'Opportunity',
                'StageName',
                'CloseDate',
                Date.today().addDays(-1),
                Date.today().addDays(1),
                u.Id
            );

        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.containsKey('grandTotal'));
    }

    /* ---------------------------------------------------
       Covers getUsers
    --------------------------------------------------- */
    @IsTest
    static void testGetUsers() {

        Test.startTest();
        List<User> users = GenericDashboardController.getUsers();
        Test.stopTest();

        System.assert(users.size() > 0);
    }
    @IsTest
    static void testDashboardByPicklistFieldsWithNullFilters() {
    
        Test.startTest();
    
        Map<String, Object> response =
            GenericDashboardController.getDashboardByLabelFields(
                'Opportunity',
                'CloseDate',
                null,          // fromDate null
                null,          // toDate null
                null,          // ownerId null
                'StageName'
            );
    
        Test.stopTest();
    
        System.assertNotEquals(null, response);
    }
        @IsTest
    static void testNonPicklistFieldIsSkipped() {
    
        User u = [SELECT Id FROM User LIMIT 1];
    
        Test.startTest();
    
        Map<String, Object> response =
            GenericDashboardController.getDashboardByLabelFields(
                'Opportunity',
                'CloseDate',
                null,
                null,
                u.Id,
                'Name,StageName' // 👈 Name is NOT a picklist
            );
    
        Test.stopTest();
    
        Map<String, Object> tables =
            (Map<String, Object>) response.get('tables');
    
        // Name should be skipped, StageName should be processed
        System.assertEquals(false, tables.containsKey('Name'));
        System.assertEquals(true, tables.containsKey('StageName'));
    }
}