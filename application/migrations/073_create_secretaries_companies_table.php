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

class Migration_Create_secretaries_companies_table extends EA_Migration
{
    /**
     * Upgrade method.
     */
    public function up(): void
    {
        if (!$this->db->table_exists('secretaries_companies')) {
            $this->dbforge->add_field([
                'id_users_secretary' => [
                    'type' => 'INT',
                    'constraint' => '11',
                    'null' => false,
                ],
                'id_companies' => [
                    'type' => 'BIGINT',
                    'constraint' => '20',
                    'unsigned' => true,
                    'null' => false,
                ],
            ]);

            $this->dbforge->add_key(['id_users_secretary', 'id_companies'], true);
            $this->dbforge->add_key('id_users_secretary');
            $this->dbforge->add_key('id_companies');

            $this->dbforge->create_table('secretaries_companies', true, ['engine' => 'InnoDB']);

            $this->db->query(
                '
                ALTER TABLE `' .
                    $this->db->dbprefix('secretaries_companies') .
                    '`
                    ADD CONSTRAINT `secretaries_companies_users_secretary` FOREIGN KEY (`id_users_secretary`) REFERENCES `' .
                    $this->db->dbprefix('users') .
                    '` (`id`)
                    ON DELETE CASCADE
                    ON UPDATE CASCADE
            ',
            );

            $this->db->query(
                '
                ALTER TABLE `' .
                    $this->db->dbprefix('secretaries_companies') .
                    '`
                    ADD CONSTRAINT `secretaries_companies_companies` FOREIGN KEY (`id_companies`) REFERENCES `' .
                    $this->db->dbprefix('companies') .
                    '` (`id`)
                    ON DELETE CASCADE
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
        if ($this->db->table_exists('secretaries_companies')) {
            $this->db->query(
                'ALTER TABLE `' .
                    $this->db->dbprefix('secretaries_companies') .
                    '` DROP FOREIGN KEY `secretaries_companies_users_secretary`',
            );

            $this->db->query(
                'ALTER TABLE `' .
                    $this->db->dbprefix('secretaries_companies') .
                    '` DROP FOREIGN KEY `secretaries_companies_companies`',
            );

            $this->dbforge->drop_table('secretaries_companies');
        }
    }
}
