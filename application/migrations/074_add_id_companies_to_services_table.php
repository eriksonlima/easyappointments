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

class Migration_Add_id_companies_to_services_table extends EA_Migration
{
    /**
     * Upgrade method.
     */
    public function up(): void
    {
        if ($this->db->table_exists('services') && !$this->db->field_exists('id_companies', 'services')) {
            $this->dbforge->add_column('services', [
                'id_companies' => [
                    'type' => 'BIGINT',
                    'constraint' => '20',
                    'unsigned' => true,
                    'null' => true,
                    'after' => 'id_service_categories',
                ],
            ]);

            $this->db->query(
                '
                ALTER TABLE `' .
                    $this->db->dbprefix('services') .
                    '`
                    ADD CONSTRAINT `services_companies` FOREIGN KEY (`id_companies`) REFERENCES `' .
                    $this->db->dbprefix('companies') .
                    '` (`id`)
                    ON DELETE SET NULL
                    ON UPDATE CASCADE
            ',
            );
        }
    }

    /**
     * Downgrade method.
     */
    public function down(): void
    {
        if ($this->db->table_exists('services') && $this->db->field_exists('id_companies', 'services')) {
            $this->db->query(
                'ALTER TABLE `' .
                    $this->db->dbprefix('services') .
                    '` DROP FOREIGN KEY `services_companies`',
            );

            $this->dbforge->drop_column('services', 'id_companies');
        }
    }
}
