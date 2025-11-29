import { LightningElement, wire, track } from 'lwc';
import getRecentChanges from '@salesforce/apex/AuditTrailController.getRecentChanges';
import resolveWithTooling from '@salesforce/apex/AuditTrailController.resolveWithTooling';
import resolveWithAI from '@salesforce/apex/AuditTrailController.resolveWithAI';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const COLUMNS = [
    { label: 'Date', fieldName: 'createdDate', type: 'date', sortable: true, initialWidth: 120 },
    { 
        label: 'Type', fieldName: 'actionType', type: 'text', initialWidth: 100,
        cellAttributes: { 
            iconName: { fieldName: 'typeIcon' }, 
            class: { fieldName: 'typeClass' }
        } 
    },
    { label: 'Section', fieldName: 'section', type: 'text', initialWidth: 150 },
    { label: 'Action', fieldName: 'action', type: 'text', initialWidth: 200, wrapText: true },
    { label: 'Display Text', fieldName: 'display', type: 'text', wrapText: true },
    { label: 'Metadata', fieldName: 'metadataType', type: 'text', initialWidth: 120 },
    { 
        label: 'API Name', 
        fieldName: 'apiName', 
        type: 'text', 
        editable: true,
        initialWidth: 200,
        cellAttributes: { iconName: { fieldName: 'iconName' }, iconLabel: { fieldName: 'iconLabel' } }
    }
];

export default class AuditTrailGenerator extends LightningElement {
    @track allData = [];
    @track filteredData = [];
    @track draftValues = [];
    columns = COLUMNS;
    selectedRows = []; // Stores only the selection state (stale objects)
    generatedXml = '';
    isLoading = false;
    currentFilter = 'All';

    get filterOptions() {
        return [
            { label: 'All', value: 'All' },
            { label: 'Created Only', value: 'Created' },
            { label: 'Updated Only', value: 'Updated' }
        ];
    }

    @wire(getRecentChanges)
    wiredLogs({ error, data }) {
        if (data) {
            this.processData(data);
        } else if (error) {
            this.showToast('Error', 'Failed to load logs: ' + error.body.message, 'error');
        }
    }

    processData(rawData) {
        this.allData = rawData.map(row => {
            const isCreated = row.actionType === 'Created';
            return {
                ...row,
                iconName: row.apiName ? 'utility:check' : 'utility:warning',
                iconLabel: row.apiName ? '' : 'Needs Resolution',
                typeIcon: isCreated ? 'utility:add' : 'utility:edit',
                typeClass: isCreated ? 'slds-text-color_success' : 'slds-text-color_default'
            };
        });
        this.applyFilter();
    }

    handleFilterChange(event) {
        this.currentFilter = event.detail.value;
        this.applyFilter();
    }

    applyFilter() {
        if (this.currentFilter === 'All') {
            this.filteredData = [...this.allData];
        } else {
            this.filteredData = this.allData.filter(row => row.actionType === this.currentFilter);
        }
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        // Keep hidden selections (items selected but filtered out of current view)
        const hiddenSelections = this.selectedRows.filter(r => 
            !this.filteredData.some(d => d.id === r.id)
        );
        this.selectedRows = [...hiddenSelections, ...selectedRows];
    }

    // --- SMART RESOLVE ---
    async handleResolve() {
        if (this.selectedRows.length === 0) return;
        this.isLoading = true;

        try {
            // STEP 1: Tooling API
            this.showToast('Step 1', 'Checking System Metadata (Tooling API)...', 'info');
            
            const cleanLogs = this.selectedRows.map(row => ({
                id: row.id,
                createdDate: row.createdDate,
                createdBy: row.createdBy,
                section: row.section,
                action: row.action,
                display: row.display,
                metadataType: row.metadataType,
                apiName: row.apiName,
                isResolved: row.isResolved || false,
                actionType: row.actionType
            }));

            const toolingResults = await resolveWithTooling({ logs: cleanLogs });
            
            // Merge Tooling results
            const resultIdMap = new Map(toolingResults.map(r => [r.id, r]));
            const mergedData = this.allData.map(row => {
                if (resultIdMap.has(row.id)) {
                    const updated = resultIdMap.get(row.id);
                    const isCreated = updated.actionType === 'Created';
                    return {
                        ...updated,
                        iconName: updated.apiName ? 'utility:check' : 'utility:warning',
                        iconLabel: updated.apiName ? '' : 'Needs Resolution',
                        typeIcon: isCreated ? 'utility:add' : 'utility:edit',
                        typeClass: isCreated ? 'slds-text-color_success' : 'slds-text-color_default'
                    };
                }
                return row;
            });

            this.processData(mergedData);

            // STEP 2: AI Fallback
            // CRITICAL: Re-evaluate what is selected based on the UPDATED mergedData
            const currentSelected = mergedData.filter(row => 
                this.selectedRows.some(sel => sel.id === row.id)
            );
            const unresolved = currentSelected.filter(row => !row.apiName);

            if (unresolved.length > 0) {
                this.showToast('Step 2', `Using AI for remaining ${unresolved.length} items...`, 'info');
                
                const displayStrings = unresolved.map(r => `Section: ${r.section} | Display: ${r.display}`);
                const aiResults = await resolveWithAI({ displayStrings });
                
                const finalData = this.allData.map(row => {
                    const lookupKey = `Section: ${row.section} | Display: ${row.display}`;
                    
                    if (aiResults[lookupKey] && !row.apiName) {
                        const newRow = { ...row, apiName: aiResults[lookupKey], isResolved: true };
                        newRow.iconName = 'utility:check';
                        newRow.iconLabel = '';
                        return newRow;
                    }
                    return row;
                });
                this.processData(finalData);
                this.showToast('Success', 'Resolution Complete.', 'success');
            } else {
                this.showToast('Success', 'All items resolved via Tooling API!', 'success');
            }

        } catch (error) {
            let msg = error.body ? error.body.message : error.message;
            this.showToast('Error', msg, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // --- GENERATE XML ---
    handleGenerateXML() {
        const typeMap = {};
        let hasMissing = false;

        // CRITICAL FIX: Refresh selection data from master list (allData)
        // This ensures we get the latest 'apiName' values populated by Tooling/AI
        const selectedIds = new Set(this.selectedRows.map(r => r.id));
        const upToDateSelections = this.allData.filter(row => selectedIds.has(row.id));

        upToDateSelections.forEach(row => {
            const type = row.metadataType && row.metadataType !== 'Unknown' ? row.metadataType : 'CustomMetadata'; 
            const name = row.apiName ? row.apiName : 'Unknown_Member';
            
            if (!row.apiName) hasMissing = true;

            if (!typeMap[type]) typeMap[type] = new Set();
            typeMap[type].add(name);
        });

        if (hasMissing) this.showToast('Warning', 'Some selected items are missing API names.', 'warning');

        let xml = '<?xml version="1.0" encoding="UTF-8"?>\n<Package xmlns="http://soap.sforce.com/2006/04/metadata">\n';
        Object.keys(typeMap).sort().forEach(type => {
            xml += '    <types>\n';
            Array.from(typeMap[type]).sort().forEach(member => {
                xml += `        <members>${member}</members>\n`;
            });
            xml += `        <name>${type}</name>\n    </types>\n`;
        });
        xml += '    <version>60.0</version>\n</Package>';
        this.generatedXml = xml;
    }

    // --- UTILS ---
    handleSave(event) {
        const updatedFields = event.detail.draftValues;
        const dataMap = new Map(this.allData.map(row => [row.id, row]));
        updatedFields.forEach(draft => {
            const row = dataMap.get(draft.id);
            if(row) Object.assign(row, draft);
        });
        this.processData(Array.from(dataMap.values()));
        this.draftValues = [];
    }

    get isResolveDisabled() { return this.selectedRows.length === 0 || this.isLoading; }
    get isGenerateDisabled() { return this.selectedRows.length === 0; }
    get selectedCountLabel() { return `${this.selectedRows.length} items selected`; }

    closeModal() { this.generatedXml = null; }
    handleCopy() {
        if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(this.generatedXml);
            this.showToast('Success', 'Copied', 'success');
        } else {
            const textarea = this.template.querySelector('lightning-textarea');
            if(textarea) { textarea.focus(); document.execCommand('copy'); }
        }
    }
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}