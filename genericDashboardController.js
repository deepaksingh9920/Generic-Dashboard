import { LightningElement, api, track } from 'lwc';
import getDashboardData from '@salesforce/apex/GenericDashboardController.getDashboardData';
import getUsers from '@salesforce/apex/GenericDashboardController.getUsers';
import getDashboardByLabelFields
    from '@salesforce/apex/GenericDashboardController.getDashboardByLabelFields';
import { NavigationMixin } from 'lightning/navigation';



export default class GenericDashboard extends NavigationMixin(LightningElement) {

    @api objectApiName;
    @api statusFieldApi;
    @api dateFieldApi;
    @api dashboardPicklistFields;

    fromDate;
    toDate;
    ownerId;

    grandTotal = 0;

    @track statusBoxes = [];
    @track users = [];
    @track tableRows = [];
    @track userOptions = [];

    @track statusTotalsRow = [];
    grandTotal = 0;

    @track statusBoxes = [];
    @track statuses = [];
    @track tableRows = [];

    @track tables = []; // label-based tables
    grandTotal = 0;


    connectedCallback() {
        this.loadUsers();
        this.loadStatusDashboard();
        this.loadLabelBasedTables();
    }

    handleApply() {
        this.loadStatusDashboard();
        this.loadLabelBasedTables();
    }



    loadUsers() {
        getUsers().then(data => {
            this.userOptions = [
                { label: 'All', value: '' },
                ...data.map(u => ({
                    label: u.Name,
                    value: u.Id
                }))
            ];
        });
    }

    loadData() {
        getDashboardData({
            objectApiName: this.objectApiName,
            statusFieldApi: this.statusFieldApi,
            dateFieldApi: this.dateFieldApi,
            fromDate: this.fromDate,
            toDate: this.toDate,
            ownerId: this.ownerId
        })
            .then(result => {

                /* ---------- STATUS BOXES ---------- */
                this.statusBoxes = Object.keys(result.statusTotals).map(status => ({
                    status,
                    count: result.statusTotals[status]
                }));

                /* ---------- TABLE DATA ---------- */
                this.statuses = result.statuses;
                const userStatusMap = result.userStatusMap;

                this.tableRows = [];
                this.statusTotalsRow = [];
                this.grandTotal = result.grandTotal;

                // initialize status totals
                const statusTotalsMap = {};
                this.statuses.forEach(st => statusTotalsMap[st] = 0);

                Object.keys(userStatusMap).forEach(user => {
                    let total = 0;

                    const statusCounts = this.statuses.map(status => {
                        const count = userStatusMap[user][status] || 0;
                        total += count;
                        statusTotalsMap[status] += count;
                        return { status, count };
                    });

                    this.tableRows.push({
                        user,
                        statusCounts,
                        total
                    });
                });

                // build last total row
                this.statusTotalsRow = this.statuses.map(status => ({
                    status,
                    count: statusTotalsMap[status]
                }));
            })
            .catch(error => {
                console.error(error);
            });
    }

    loadStatusDashboard() {
        getDashboardData({
            objectApiName: this.objectApiName,
            statusFieldApi: this.statusFieldApi,
            dateFieldApi: this.dateFieldApi,
            fromDate: this.fromDate,
            toDate: this.toDate,
            ownerId: this.ownerId
        })
            .then(result => {

                /* ---------- STATUS BOXES ---------- */
                this.statusBoxes = Object.keys(result.statusTotals).map(status => ({
                    status,
                    count: result.statusTotals[status]
                }));

                /* ---------- STATUS TABLE ---------- */
                this.statuses = result.statuses;
                const userStatusMap = result.userStatusMap;

                this.tableRows = [];
                this.statusTotalsRow = [];
                this.grandTotal = result.grandTotal;

                // initialize totals
                const statusTotalsMap = {};
                this.statuses.forEach(st => statusTotalsMap[st] = 0);

                Object.keys(userStatusMap).forEach(user => {
                    let total = 0;

                    const statusCounts = this.statuses.map(status => {
                        const count = userStatusMap[user][status] || 0;
                        total += count;
                        statusTotalsMap[status] += count;

                        return { status, count };
                    });

                    this.tableRows.push({
                        user,
                        statusCounts,
                        total
                    });
                });

                // build totals row
                this.statusTotalsRow = this.statuses.map(status => ({
                    status,
                    count: statusTotalsMap[status]
                }));
            })
            .catch(error => {
                console.error(error);
            });
    }

    handleFromDate(event) {
        this.fromDate = event.target.value;
    }

    handleToDate(event) {
        this.toDate = event.target.value;
    }

    handleUserChange(event) {
        this.ownerId = event.detail.value;
    }

    loadLabelBasedTables() {
        getDashboardByLabelFields({
            objectApiName: this.objectApiName,
            dateFieldApi: this.dateFieldApi,
            fromDate: this.fromDate,
            toDate: this.toDate,
            ownerId: this.ownerId,
            dashboardPicklistFields : this.dashboardPicklistFields
        })
            .then(result => {
                this.tables = [];

                Object.keys(result.tables).forEach(field => {
                    const tableData = result.tables[field];
                    const picklistValues = tableData.picklistValues;
                    const userData = tableData.userData;

                    const rows = [];
                    const totalsMap = {};
                    let grandTotal = 0;

                    picklistValues.forEach(v => totalsMap[v] = 0);

                    Object.keys(userData).forEach(user => {
                        let rowTotal = 0;

                        const values = picklistValues.map(val => {
                            const count = userData[user][val] || 0;
                            totalsMap[val] += count;
                            rowTotal += count;
                            grandTotal += count;
                            return { key: val, count };
                        });

                        rows.push({ user, values, total: rowTotal });
                    });

                    const totalsArray = picklistValues.map(v => ({
                        key: v,
                        count: totalsMap[v]
                    }));

                    this.tables.push({
                        field,
                        fieldLabel: field.replace('__c', '').replace(/_/g, ' '),
                        picklistValues,
                        rows,
                        totalsArray,
                        grandTotal
                    });
                });
            })
            .catch(err => console.error(err));
    }

    get hasTables() {
        return this.tables && this.tables.length > 0;
    }

    /*
        buildListViewUrl(filters) {
            const filterParts = [];
    
            Object.keys(filters).forEach(field => {
                filterParts.push(`${field}=${encodeURIComponent(filters[field])}`);
            });
    
            return filterParts.join('&');
        }
    
        handleStatusBoxClick(event) {
            const status = event.target.dataset.status;
    
            this.navigateToList({
                [this.statusFieldApi]: status
            });
        }
    
        handleStatusCellClick(event) {
            const status = event.target.dataset.status;
            const userName = event.target.dataset.user;
            const ownerId = "005gK000001IW8vQAG";
    
            createAndOpenListView({
                objectApiName: this.objectApiName,
                status: status,
                ownerId: ownerId
            })
            .then(listViewId => {
    
                // ✅ Generate URL using NavigationMixin (CSP safe)
                this[NavigationMixin.GenerateUrl]({
                    type: 'standard__objectPage',
                    attributes: {
                        objectApiName: this.objectApiName,
                        actionName: 'list'
                    },
                    state: {
                        filterName: listViewId
                    }
                }).then(url => {
                    // ✅ window.open on generated URL is allowed
                    window.open(url, '_blank');
                });
    
            })
            .catch(error => {
                console.error('List view creation failed', error);
            });
        }
    
    
    
        getUserIdByName(userName) {
            const user = this.users.find(u => u.Name === userName);
            return user ? user.Id : null;
        }
    
    
    
    
    
        handleLabelCellClick(event) {
            const field = event.target.dataset.field;
            const value = event.target.dataset.value;
            const userName = event.target.dataset.user;
            this.prepareSoqlQuery();
            console.log('event.target.dataset.field',event.target.dataset.field,' - ',event.target.dataset.value,' - ',event.target.dataset.user)
            this.navigateToList({
                [field]: value,
                'Owner.Name': userName
            });
        }
    
        navigateToList(extraFilters) {
            const filters = { ...extraFilters };
    
            if (this.fromDate) {
                filters[this.dateFieldApi + '__gte'] = this.fromDate;
            }
            if (this.toDate) {
                filters[this.dateFieldApi + '__lte'] = this.toDate;
            }
    
            this[NavigationMixin.GenerateUrl]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: this.objectApiName,
                    actionName: 'list'
                },
                state: filters
            }).then(url => {
                window.open(url, '_blank');
            });
        }
        */
}