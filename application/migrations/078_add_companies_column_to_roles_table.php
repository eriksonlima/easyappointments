<?php defined('BASEPATH') or exit('No direct script access allowed');

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

class Migration_Add_companies_column_to_roles_table extends EA_Migration
{
    /**
     * Upgrade method.
     */
    public function up(): void
    {
        if (!$this->db->field_exists('companies', 'roles')) {
            $this->dbforge->add_column('roles', [
                'companies' => [
                    'type' => 'INT',
                    'constraint' => '11',
                    'null' => true,
                ],
            ]);

            $this->db->update('roles', ['companies' => 15], ['slug' => 'admin']);
            $this->db->update('roles', ['companies' => 15], ['slug' => 'company_admin']);
            $this->db->where('slug !=', 'admin')->where('slug !=', 'company_admin')->update('roles', ['companies' => 0]);
        }
    }

    /**
     * Downgrade method.
     */
    public function down(): void
    {
        if ($this->db->field_exists('companies', 'roles')) {
            $this->dbforge->drop_column('roles', 'companies');
        }
    }
}
