import { LightningElement, api, wire } from 'lwc';
import FORM_FACTOR from '@salesforce/client/formFactor'
import { NavigationMixin } from "lightning/navigation";
import { refreshApex } from '@salesforce/apex';
import getPlaygroupSessionInfo from '@salesforce/apex/playgroupSessionLWCController.getPlaygroupSessionInfo';

export default class PlaygroupSessionMain extends NavigationMixin(LightningElement) {
    @api recordId;
    animalIds = [];
    wireResponse;
    showSpinner = true;
    animals = [];
    playgroupContacts = [];
    animalsForCopy = [];
    sessionIdForCopy;
    toDoListAction;
    session;
    sessionPlaygroupLeader;
    toggleDropdown = false;

    customLookupFields = ["Name","Email","Title"];
    customLookupDisplayFields = 'Name, Email, Title';
    customLookupCreateNewFields = ['FirstName', 'LastName', 'Title', 'Department', 'Email'];
    customLookupExpandedField = false;
    formFactor = FORM_FACTOR;

    sessionPendingUpdate = false;
    sessionUpdateInProgress = false;
    sessionInfoError;
    error;

    showToDoList = false;
    refresh = false;

    @wire(getPlaygroupSessionInfo, {sessionId: '$recordId'})
    response(result){
        this.wireResponse = result;
        if(result.data ){
            this.session = result.data.playgroupSession;
            this.sessionPlaygroupLeader = result.data.playgroupSession.Playgroup_Leader__c;
            if(result.data.animalPlaygroups){
                this.animals = result.data.animalPlaygroups;
            }
            if(result.data.playgroupContacts){
                this.playgroupContacts = result.data.playgroupContacts;
            }
            this.showSpinner = false;
        } else if(result.error){
            this.sessionInfoError = result.error;
            this.showSpinner = false;
        }
    }

    // connectedCallback(){
    //     this.animalsForCopy = [];
    //     this.sessionIdForCopy = undefined;
    // }

    // handleCopyPlaygroup(){
    //     this.showSpinner = true;
    //     startPlaygroupSession({sessionId: this.recordId})
    //     .then((response) => {
    //         this.recordId = response;
    //     })
    //     .finally(() => {
    //         this.showSpinner = false;
    //     })
    // }

    customLookupEvent(event){
        this.sessionPlaygroupLeader = event.detail.data.recordId;
        this.sessionPendingUpdate = true;
    }

    handleCustomLookupExpandSearch(event){
        let data = event.detail.data;
        this.customLookupExpandedField = data.expandField;
    }

    handleSaveSession(event){
        event.preventDefault();
        const fields = event.detail.fields;
        fields['Playgroup_Leader__c'] = this.sessionPlaygroupLeader;
        this.template.querySelector('lightning-record-edit-form').submit(fields);
        this.sessionUpdateInProgress = true;
    }

    handleOnChangeSessionInfo(){
        this.sessionPendingUpdate = true;
    }

    handleSessionUpdateSuccess(){
        this.sessionPendingUpdate = false;
        this.sessionUpdateInProgress = false;
        this.toggleDropdown = false;
    }

    handleSessionUpdateError(event){
        const error = event.detail.detail;
        this.error = error;
    }

    handleEditSession(){
        this.toDoListAction = 'edit';
        this.animals.forEach(animal => {
            this.animalsForCopy.push({label: animal.Animal_Name__c, name: animal.Animal__c});
        });
        this.sessionIdForCopy = this.session.Id;
        
        this.showToDoList = true;
        this.handleToggleDropdown();
    }

    handleCreateNewSession(){
        this.toDoListAction = 'new';
        this.animalsForCopy = [];
        this.sessionIdForCopy = undefined;
        this.showToDoList = true;
        this.handleToggleDropdown();
    }

    handleCopySession(){
        this.toDoListAction = 'copy';
        this.animals.forEach(animal => {
            this.animalsForCopy.push({label: animal.Animal_Name__c, name: animal.Animal__c});
        });
        this.sessionIdForCopy = this.session.Id;
        
        this.showToDoList = true;
        this.handleToggleDropdown();
    }

    async handleReset() {
        await this.resetFields();
        this.sessionPendingUpdate = false;
        this.handleToggleDropdown();
    }

    resetFields(){
        const inputFields = this.template.querySelectorAll('lightning-input-field');
        if (inputFields) {
            inputFields.forEach(field => {
                field.reset();
            });
        }
    }

    handleToggleDropdown(){
        this.toggleDropdown = !this.toggleDropdown;
    }

    handleCopyEvent(event){
        window.console.log('in handleCopyEvent');
        this.playgroupContacts = [];
        this.sessionPlaygroupLeader = undefined;
        this.showToDoList = false;
        this.recordId = event.detail.id;
        refreshApex(this.wireResponse);
    }

    handleEditEvent(event){
        this.showToDoList = false;
        refreshApex(this.wireResponse);
    }

    handleNavigateToSession(){
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.session.Id,
                objectApiName: 'Playgroup_Session__c',
                actionName: 'view'
            }
        });
        refreshApex(this.wireResponse);
    }

    handleAnimalRemovedEvent(){
        refreshApex(this.wireResponse);
    }

    handleContactEvent(){
        this.refresh = !this.refresh;
    }

    get customLookupLeaderDeviceSize(){
        if(FORM_FACTOR == 'Large'){
            return this.customLookupExpandedField ? '6' : '3';
        }
        if(FORM_FACTOR == 'Medium'){
            return this.customLookupExpandedField ? '12' : '6';
        }
    }

    get smallForm(){
        return this.formFactor == 'Small';
    }

    get currentDateTime(){
        if(!this.session){
            return (new Date().toISOString());
        }
    }

    get customLookupValueId(){
        if(this.sessionPlaygroupLeader){
            return this.sessionPlaygroupLeader;
        }
    }

    get dropdownIcon(){
        return this.toggleDropdown ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get hasAnimalList(){
        return this.animals.length > 0;
    }

    get disableSaveButton(){
        return !this.sessionPendingUpdate;
    }

    get isSessionPendingUpdate(){
        return this.sessionPendingUpdate;
    }
    get sessionButtonLabel(){
        return 'Session: ' + this.session.Name;
    }
}