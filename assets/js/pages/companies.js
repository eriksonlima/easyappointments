/* ----------------------------------------------------------------------------
 * Easy!Appointments - Online Appointment Scheduler
 *
 * @package     EasyAppointments
 * @author      A.Tselegidis <alextselegidis@gmail.com>
 * @copyright   Copyright (c) Alex Tselegidis
 * @license     https://opensource.org/licenses/GPL-3.0 - GPLv3
 * @link        https://easyappointments.org
 * @since       v1.6.0
 * ---------------------------------------------------------------------------- */

/**
 * Companies page.
 *
 * This module implements the functionality of the companies page.
 */
App.Pages.Companies = (function () {
    const $companies = $('#companies');
    const $id = $('#id');
    const $name = $('#name');
    const $slug = $('#slug');
    const $email = $('#email');
    const $phoneNumber = $('#phone-number');
    const $address = $('#address');
    const $city = $('#city');
    const $state = $('#state');
    const $zipCode = $('#zip-code');
    const $timezone = $('#timezone');
    const $language = $('#language');
    const $description = $('#description');
    const $notes = $('#notes');
    const $isPrivate = $('#is-private');
    const $filterCompanies = $('#filter-companies');
    let filterResults = {};
    let filterLimit = 20;

    /**
     * Add page event listeners.
     */
    function addEventListeners() {
        /**
         * Event: Filter Companies Form "Submit"
         */
        $companies.on('submit', '#filter-companies form', (event) => {
            event.preventDefault();
            const key = $filterCompanies.find('.key').val();
            $filterCompanies.find('.selected').removeClass('selected');
            App.Pages.Companies.resetForm();
            App.Pages.Companies.filter(key);
        });

        /**
         * Event: Filter Company Row "Click"
         */
        $companies.on('click', '.company-row', (event) => {
            if ($filterCompanies.find('.filter').prop('disabled')) {
                $filterCompanies.find('.results').css('color', '#AAA');
                return;
            }

            const companyId = $(event.currentTarget).attr('data-id');
            const company = filterResults.find((r) => Number(r.id) === Number(companyId));

            App.Pages.Companies.display(company);
            $filterCompanies.find('.selected').removeClass('selected');
            $(event.currentTarget).addClass('selected');
            $('#edit-company, #delete-company').prop('disabled', false);

            $('#companies-page').addClass('editing');
            $companies.find('.add-edit-delete-group').hide();
            $companies.find('.save-cancel-group').show();
            $companies.find('#delete-company').show();
            $companies.find('.record-details').find('input, select, textarea').prop('disabled', false);
            $companies.find('.record-details .form-label span').prop('hidden', false);
            $filterCompanies.find('button').prop('disabled', true);
            $filterCompanies.find('.results').css('color', '#AAA');
            $('#company-providers input:checkbox').prop('disabled', false);
        });

        /**
         * Event: Add New Company Button "Click"
         */
        $companies.on('click', '#add-company', () => {
            App.Pages.Companies.resetForm();
            $('#companies-page').addClass('editing');
            $companies.find('.add-edit-delete-group').hide();
            $companies.find('.save-cancel-group').show();
            $companies.find('#delete-company').hide();
            $companies.find('.record-details').find('input, select, textarea').prop('disabled', false);
            $companies.find('.record-details .form-label span').prop('hidden', false);
            $filterCompanies.find('button').prop('disabled', true);
            $filterCompanies.find('.results').css('color', '#AAA');
            $('#company-providers input:checkbox').prop('disabled', false);

            $name.val('');
            $slug.val('');
            $email.val('');
            $phoneNumber.val('');
        });

        /**
         * Event: Cancel Company Button "Click"
         */
        $companies.on('click', '#cancel-company', () => {
            const id = $id.val();
            App.Pages.Companies.resetForm();
            $('#companies-page').removeClass('editing');

            if (id !== '') {
                App.Pages.Companies.select(id, true);
            }
        });

        /**
         * Event: Save Company Button "Click"
         */
        $companies.on('click', '#save-company', () => {
            const company = {
                name: $name.val(),
                slug: $slug.val() || undefined,
                email: $email.val() || undefined,
                phone_number: $phoneNumber.val() || undefined,
                address: $address.val() || undefined,
                city: $city.val() || undefined,
                state: $state.val() || undefined,
                zip_code: $zipCode.val() || undefined,
                timezone: $timezone.val() || undefined,
                language: $language.val() || undefined,
                description: $description.val() || undefined,
                notes: $notes.val() || undefined,
                is_private: Number($isPrivate.prop('checked')),
            };

            company.providers = [];
            $('#company-providers input:checkbox').each((index, checkboxEl) => {
                if ($(checkboxEl).prop('checked')) {
                    company.providers.push($(checkboxEl).attr('data-id'));
                }
            });

            if ($id.val() !== '') {
                company.id = $id.val();
            }

            if (!App.Pages.Companies.validate()) {
                return;
            }

            App.Pages.Companies.save(company);
        });

        /**
         * Event: Edit Company Button "Click"
         */
        $companies.on('click', '#edit-company', () => {
            $('#companies-page').addClass('editing');
            $companies.find('.add-edit-delete-group').hide();
            $companies.find('.save-cancel-group').show();
            $companies.find('.record-details').find('input, select, textarea').prop('disabled', false);
            $companies.find('.record-details .form-label span').prop('hidden', false);
            $filterCompanies.find('button').prop('disabled', true);
            $filterCompanies.find('.results').css('color', '#AAA');
            $('#company-providers input:checkbox').prop('disabled', false);
        });

        /**
         * Event: Delete Company Button "Click"
         */
        $companies.on('click', '#delete-company', () => {
            const companyId = $id.val();
            const buttons = [
                {
                    text: lang('cancel'),
                    click: (event, messageModal) => {
                        messageModal.hide();
                    },
                },
                {
                    text: lang('delete'),
                    click: (event, messageModal) => {
                        App.Pages.Companies.remove(companyId);
                        messageModal.hide();
                    },
                },
            ];

            App.Utils.Message.show(lang('delete_company'), lang('delete_record_prompt'), buttons);
        });

        /**
         * Event: Select All Providers Button "Click"
         */
        $companies.on('click', '#select-all-providers', () => {
            $('#company-providers input:checkbox').prop('checked', true);
        });

        /**
         * Event: Select None Providers Button "Click"
         */
        $companies.on('click', '#select-none-providers', () => {
            $('#company-providers input:checkbox').prop('checked', false);
        });

        /**
         * Event: Provider checkbox "change" — show/hide the working plan button
         */
        $companies.on('change', '#company-providers input[type=checkbox][data-id]', (event) => {
            const $checkbox = $(event.currentTarget);
            const $row = $checkbox.closest('.d-flex');
            const $btn = $row.find('.set-provider-working-plan');

            if ($checkbox.prop('checked')) {
                $btn.removeClass('d-none');
            } else {
                $btn.addClass('d-none');
            }
        });

        /**
         * Event: Set Provider Working Plan Button "Click"
         */
        $companies.on('click', '.set-provider-working-plan', (event) => {
            event.stopPropagation();

            const $btn = $(event.currentTarget);
            const providerId = $btn.data('provider-id');
            const providerName = $btn.data('provider-name');
            const companyId = $id.val();

            $('#modal-provider-name').text(providerName);
            $('#modal-provider-id').val(providerId);
            $('#modal-company-id').val(companyId);

            // Reset to default before loading
            $('#company-working-plan-table tbody tr').each((i, row) => {
                const $row = $(row);
                $row.find('.day-active').prop('checked', false);
                $row.find('.day-start').val('09:00').prop('disabled', true);
                $row.find('.day-end').val('18:00').prop('disabled', true);
                $row.find('.day-conflict').empty();
                $row.removeClass('table-warning');
            });
            $('#provider-working-plan-modal .conflict-alert').hide().empty();

            const loadPlans = [];

            if (companyId) {
                loadPlans.push(
                    App.Http.Companies.getProviderWorkingPlan(companyId, providerId).then((response) => {
                        if (response.working_plan) {
                            App.Pages.Companies.applyWorkingPlanToModal(response.working_plan);
                        }
                    }),
                );

                loadPlans.push(
                    App.Http.Companies.getProviderAllWorkingPlans(providerId, companyId).then((allPlans) => {
                        App.Pages.Companies.applyOccupiedSlotsToModal(allPlans);
                    }),
                );
            }

            Promise.all(loadPlans).finally(() => {
                bootstrap.Modal.getOrCreateInstance(document.getElementById('provider-working-plan-modal')).show();
            });
        });

        /**
         * Event: Day Active Checkbox "Change" inside working plan modal
         */
        $('#provider-working-plan-modal').on('change', '.day-active', (event) => {
            const $checkbox = $(event.currentTarget);
            const $row = $checkbox.closest('tr');
            const active = $checkbox.prop('checked');
            $row.find('.day-start, .day-end').prop('disabled', !active);
        });

        /**
         * Event: Save Provider Working Plan Button "Click"
         */
        $('#save-provider-working-plan').on('click', () => {
            const companyId = $('#modal-company-id').val();
            const providerId = $('#modal-provider-id').val();

            if (!companyId) {
                App.Layouts.Backend.displayNotification(lang('working_plan_no_company') || 'Save the company first.');
                return;
            }

            const workingPlan = {};

            $('#company-working-plan-table tbody tr').each((i, row) => {
                const $row = $(row);
                const day = $row.data('day');
                const active = $row.find('.day-active').prop('checked');

                if (active) {
                    workingPlan[day] = {
                        start: $row.find('.day-start').val(),
                        end: $row.find('.day-end').val(),
                        breaks: [],
                    };
                } else {
                    workingPlan[day] = null;
                }
            });

            const request = App.Http.Companies.setProviderWorkingPlan(companyId, providerId, workingPlan);

            request.done(() => {
                bootstrap.Modal.getOrCreateInstance(document.getElementById('provider-working-plan-modal')).hide();
                App.Layouts.Backend.displayNotification(lang('working_plan_saved') || 'Working plan saved!');
            });

            request.fail((jqXHR) => {
                if (jqXHR.status === 422) {
                    let conflicts = [];
                    try {
                        conflicts = JSON.parse(jqXHR.responseText).conflicts || [];
                    } catch (e) {
                        // ignore parse error
                    }
                    const conflictMessages = conflicts.map(
                        (c) => `${lang(c.day)}: ${lang('occupied_by')} "${c.context}" (${c.existing})`,
                    );
                    const $alert = $('#provider-working-plan-modal .conflict-alert');
                    $alert.html(
                        `<strong>${lang('schedule_conflict')}</strong><ul class="mb-0 mt-1">${conflictMessages.map((m) => `<li>${m}</li>`).join('')}</ul>`,
                    ).show();
                } else {
                    App.Layouts.Backend.displayNotification(
                        (lang('unexpected_issues') || 'An unexpected error occurred.') + ' [HTTP ' + jqXHR.status + ']',
                    );
                    console.error('Error saving working plan:', jqXHR.status, jqXHR.responseText);
                }
            });
        });
    }

    /**
     * Save company record to database.
     *
     * @param {Object} company
     */
    function save(company) {
        App.Http.Companies.save(company).then((response) => {
            App.Layouts.Backend.displayNotification(lang('company_saved'));
            App.Pages.Companies.resetForm();
            $('#companies-page').removeClass('editing');
            $filterCompanies.find('.key').val('');
            App.Pages.Companies.filter('', response.id, true);
        });
    }

    /**
     * Delete a company record.
     *
     * @param {Number} id
     */
    function remove(id) {
        App.Http.Companies.destroy(id).then(() => {
            App.Layouts.Backend.displayNotification(lang('company_deleted'));
            App.Pages.Companies.resetForm();
            $('#companies-page').removeClass('editing');
            App.Pages.Companies.filter($filterCompanies.find('.key').val());
        });
    }

    /**
     * Validate company form.
     *
     * @return {Boolean}
     */
    function validate() {
        $companies.find('.is-invalid').removeClass('is-invalid');
        $companies.find('.form-message').removeClass('alert-danger').hide();

        try {
            let missingRequired = false;

            $companies.find('.required').each((index, requiredField) => {
                if (!$(requiredField).val()) {
                    $(requiredField).addClass('is-invalid');
                    missingRequired = true;
                }
            });

            if (missingRequired) {
                throw new Error(lang('fields_are_required'));
            }

            if ($email.val() && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test($email.val())) {
                $email.addClass('is-invalid');
                throw new Error(lang('invalid_email'));
            }

            return true;
        } catch (error) {
            $companies.find('.form-message').addClass('alert-danger').text(error.message).show();
            return false;
        }
    }

    /**
     * Reset the company form back to its initial state.
     */
    function resetForm() {
        $filterCompanies.find('.selected').removeClass('selected');
        $filterCompanies.find('button').prop('disabled', false);
        $filterCompanies.find('.results').css('color', '');

        $companies.find('.record-details').find('input, select, textarea').val('').prop('disabled', true);
        $companies.find('.record-details .form-label span').prop('hidden', true);
        $companies.find('.record-details #is-private').prop('checked', false);

        $companies.find('.add-edit-delete-group').show();
        $companies.find('.save-cancel-group').hide();
        $('#edit-company, #delete-company').prop('disabled', true);

        $companies.find('.record-details .is-invalid').removeClass('is-invalid');
        $companies.find('.record-details .form-message').hide();

        $('#company-providers input:checkbox').prop('disabled', true).prop('checked', false);
        $('#company-providers .set-provider-working-plan').addClass('d-none');
        $('#select-all-providers, #select-none-providers').prop('disabled', true);

        // Clear linked secretaries.
        $('#company-secretaries .secretary-badge').remove();
        $('#company-secretaries-empty').removeClass('d-none');
    }

    /**
     * Display a company record into the form.
     *
     * @param {Object} company
     */
    function display(company) {
        $id.val(company.id);
        $name.val(company.name);
        $slug.val(company.slug);
        $email.val(company.email);
        $phoneNumber.val(company.phone_number);
        $address.val(company.address);
        $city.val(company.city);
        $state.val(company.state);
        $zipCode.val(company.zip_code);
        $timezone.val(company.timezone);
        $language.val(company.language);
        $description.val(company.description);
        $notes.val(company.notes);
        $isPrivate.prop('checked', Boolean(company.is_private));

        $('#company-providers input:checkbox').prop('checked', false);
        $('.set-provider-working-plan').addClass('d-none');

        if (company.providers) {
            company.providers.forEach((providerId) => {
                const $checkbox = $(`#company-providers input[data-id="${providerId}"]`);
                $checkbox.prop('checked', true);
                $checkbox.closest('.d-flex').find('.set-provider-working-plan').removeClass('d-none');
            });
        }

        // Show linked secretaries (read-only).
        const $secContainer = $('#company-secretaries');
        const $secEmpty = $('#company-secretaries-empty');
        $secContainer.find('.secretary-badge').remove();
        const secretariesMap = vars('company_secretaries_map') || {};
        const linkedSecretaries = secretariesMap[Number(company.id)] || [];

        if (linkedSecretaries.length) {
            $secEmpty.addClass('d-none');
            linkedSecretaries.forEach((sec) => {
                $secContainer.append(
                    $('<span/>', {
                        'class': 'secretary-badge badge rounded-pill bg-secondary me-1 mb-1',
                        'text': sec.name,
                    }),
                );
            });
        } else {
            $secEmpty.removeClass('d-none');
        }
    }

    /**
     * Apply a working plan object to the modal table.
     *
     * @param {Object} workingPlan
     */
    function applyWorkingPlanToModal(workingPlan) {
        const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

        days.forEach((day) => {
            const plan = workingPlan[day];
            const $row = $(`#company-working-plan-table tr[data-day="${day}"]`);

            if (plan) {
                $row.find('.day-active').prop('checked', true);
                $row.find('.day-start').val(plan.start).prop('disabled', false);
                $row.find('.day-end').val(plan.end).prop('disabled', false);
            } else {
                $row.find('.day-active').prop('checked', false);
                $row.find('.day-start').val('09:00').prop('disabled', true);
                $row.find('.day-end').val('18:00').prop('disabled', true);
            }
        });
    }

    /**
     * Show occupied slots (from other companies / particular) in the modal table.
     *
     * @param {Object} allPlans  Object keyed by 'company:{id}' or 'particular', each with {label, plan}.
     */
    function applyOccupiedSlotsToModal(allPlans) {
        const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

        days.forEach((day) => {
            const $row = $(`#company-working-plan-table tr[data-day="${day}"]`);
            const $cell = $row.find('.day-conflict');
            const labels = [];

            Object.values(allPlans).forEach((entry) => {
                const dayPlan = entry.plan[day];
                if (dayPlan && dayPlan.start && dayPlan.end) {
                    labels.push(`<span class="badge bg-warning text-dark">${entry.label}: ${dayPlan.start}–${dayPlan.end}</span>`);
                }
            });

            if (labels.length > 0) {
                $cell.html(labels.join(' '));
                $row.addClass('table-warning');
            } else {
                $cell.empty();
                $row.removeClass('table-warning');
            }
        });
    }

    /**
     * Filter companies by keyword.
     *
     * @param {String} keyword
     * @param {Number} selectId
     * @param {Boolean} show
     */
    function filter(keyword, selectId = null, show = false) {
        App.Http.Companies.search(keyword, filterLimit).then((response) => {
            filterResults = response;

            $filterCompanies.find('.results').empty();

            response.forEach((company) => {
                $filterCompanies.find('.results').append(App.Pages.Companies.getFilterHtml(company)).append($('<hr/>'));
            });

            if (response.length === 0) {
                $filterCompanies.find('.results').append(
                    $('<em/>', {
                        text: lang('no_records_found'),
                    }),
                );
            } else if (response.length === filterLimit) {
                $('<button/>', {
                    type: 'button',
                    class: 'btn btn-outline-secondary w-100 load-more text-center',
                    text: lang('load_more'),
                    click: () => {
                        filterLimit += 20;
                        App.Pages.Companies.filter(keyword, selectId, show);
                    },
                }).appendTo('#filter-companies .results');
            }

            if (selectId) {
                App.Pages.Companies.select(selectId, show);
            }
        });
    }

    /**
     * Get Filter HTML row for a company.
     *
     * @param {Object} company
     *
     * @return {jQuery}
     */
    function getFilterHtml(company) {
        return $('<div/>', {
            class: 'company-row entry',
            'data-id': company.id,
            html: [
                $('<strong/>', {text: company.name}),
                $('<br/>'),
                $('<small/>', {
                    class: 'text-muted',
                    text: company.email || company.phone_number || '',
                }),
                $('<br/>'),
            ],
        });
    }

    /**
     * Select a record from filter results.
     *
     * @param {Number} id
     * @param {Boolean} show
     */
    function select(id, show = false) {
        $filterCompanies.find('.selected').removeClass('selected');
        $filterCompanies.find(`.company-row[data-id="${id}"]`).addClass('selected');

        if (show) {
            const company = filterResults.find((r) => Number(r.id) === Number(id));
            App.Pages.Companies.display(company);
            $('#edit-company, #delete-company').prop('disabled', false);
        }
    }

    /**
     * Initialize the module.
     */
    function initialize() {
        App.Pages.Companies.resetForm();
        App.Pages.Companies.filter('');
        App.Pages.Companies.addEventListeners();
    }

    document.addEventListener('DOMContentLoaded', initialize);

    return {
        filter,
        save,
        remove,
        validate,
        getFilterHtml,
        resetForm,
        display,
        select,
        addEventListeners,
        applyWorkingPlanToModal,
        applyOccupiedSlotsToModal,
    };
})();
