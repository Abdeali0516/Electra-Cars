import { LightningElement, wire } from 'lwc';
import getCurrentUserInfo from '@salesforce/apex/CreateCaseController.getCurrentUserInfo';
import createCase from '@salesforce/apex/CreateCaseController.createCase';
import linkFilesToCase from '@salesforce/apex/CreateCaseController.linkFilesToCase';

export default class CreateCase extends LightningElement {
    title = '';
    description = '';
    suppliedPhone = '';
    priority = 'Medium';

    contactId = null;
    accountId = null;

    uploadedFiles = [];

    isSubmitting = false;
    showSuccessScreen = false;
    createdCaseNumber = '';

    showError = false;
    errorMessage = '';
    errorTimerId;

    priorityOptions = [
        { value: 'High', label: 'High', colorClass: 'priority-high' },
        { value: 'Medium', label: 'Medium', colorClass: 'priority-medium' },
        { value: 'Low', label: 'Low', colorClass: 'priority-low' }
    ];

    @wire(getCurrentUserInfo)
    wiredUserInfo({ error, data }) {
        if (data) {
            this.suppliedPhone = data.phone || '';
            this.contactId = data.contactId;
            this.accountId = data.accountId;
        } else if (error) {
            console.error('Error fetching user info:', error);
        }
    }

    get priorityOptionsWithStyle() {
        return this.priorityOptions.map(option => ({
            ...option,
            isSelected: this.priority === option.value,
            buttonClass: `priority-btn ${option.colorClass} ${this.priority === option.value ? 'selected' : ''}`
        }));
    }

    get isFormValid() {
        return this.title && this.priority;
    }

    handleTitleChange(event) {
        this.title = event.target.value;
    }

    handleDescriptionChange(event) {
        this.description = event.target.value;
    }

    handlePhoneChange(event) {
        this.suppliedPhone = event.target.value;
    }

    handlePriorityChange(event) {
        this.priority = event.currentTarget.dataset.value;
    }

    handleUploadFinished(event) {
        const newFiles = event.detail.files;
        this.uploadedFiles = [...this.uploadedFiles, ...newFiles];
    }

    handleRemoveFile(event) {
        const fileId = event.currentTarget.dataset.id;
        this.uploadedFiles = this.uploadedFiles.filter(file => file.documentId !== fileId);
    }

    showErrorAlert(message) {
        if (this.errorTimerId) {
            clearTimeout(this.errorTimerId);
        }
        this.showError = true;
        this.errorMessage = message;

        this.errorTimerId = setTimeout(() => {
            this.showError = false;
            this.errorMessage = '';
        }, 6000);
    }

    async handleSubmit() {
        if (!this.title) {
            this.showErrorAlert('Please enter a title');
            return;
        }
        if (!this.priority) {
            this.showErrorAlert('Please select a priority');
            return;
        }

        this.isSubmitting = true;

        try {
            const result = await createCase({
                subject: this.title,
                description: this.description,
                suppliedPhone: this.suppliedPhone,
                priority: this.priority,
                contactId: this.contactId,
                accountId: this.accountId
            });

            if (result.success) {
                if (this.uploadedFiles.length > 0) {
                    const fileIds = this.uploadedFiles.map(f => f.documentId);
                    await linkFilesToCase({
                        caseId: result.caseId,
                        fileIds: fileIds
                    });
                }

                this.createdCaseNumber = result.caseNumber;
                this.showSuccessScreen = true;
            } else {
                this.showErrorAlert(result.errorMessage || 'Failed to create case. Please try again.');
            }
        } catch (error) {
            console.error('Error creating case:', error);
            this.showErrorAlert(error.body?.message || 'An unexpected error occurred. Please try again.');
        } finally {
            this.isSubmitting = false;
        }
    }

    handleNewCase() {
        this.title = '';
        this.description = '';
        this.suppliedPhone = '';
        this.priority = 'Medium';
        this.uploadedFiles = [];
        this.showSuccessScreen = false;
        this.createdCaseNumber = '';

        getCurrentUserInfo()
            .then(data => {
                this.suppliedPhone = data.phone || '';
            })
            .catch(error => console.error('Error re-fetching user info:', error));
    }

    disconnectedCallback() {
        if (this.errorTimerId) {
            clearTimeout(this.errorTimerId);
        }
    }
}